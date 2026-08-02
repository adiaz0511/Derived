#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
version=""
architecture_mode="native"
output_dir="$project_root/dist"
sign_identity="${DERIVED_SIGN_IDENTITY:-}"
notary_profile="${DERIVED_NOTARY_PROFILE:-}"
notary_keychain="${DERIVED_NOTARY_KEYCHAIN:-}"
unsigned=false
notarize=false
dry_run=false
keep_work=false
sparkle_private_key=""

function usage {
  cat <<'EOF'
Usage: scripts/build-release-dmg.sh --version VERSION [options]

Options:
  --architectures native|universal  Build for this Mac or arm64 and x86_64.
  --output-dir PATH                 Write release artifacts to PATH.
  --sign-identity NAME             Developer ID Application identity.
  --notary-profile NAME            notarytool keychain profile.
  --notarize                       Submit, wait, staple, and assess the DMG.
  --unsigned                       Build without signing or notarization.
  --dry-run                        Validate options and print the release plan.
  --keep-work                      Retain the temporary build directory.
  --sparkle-private-key PATH       Generate a signed Sparkle appcast using this private key.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --version) version="${2:?Missing value for --version}"; shift 2 ;;
    --architectures) architecture_mode="${2:?Missing value for --architectures}"; shift 2 ;;
    --output-dir) output_dir="${2:A}"; shift 2 ;;
    --sign-identity) sign_identity="${2:?Missing value for --sign-identity}"; shift 2 ;;
    --notary-profile) notary_profile="${2:?Missing value for --notary-profile}"; shift 2 ;;
    --notarize) notarize=true; shift ;;
    --unsigned) unsigned=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    --keep-work) keep_work=true; shift ;;
    --sparkle-private-key) sparkle_private_key="${2:A}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

[[ -n "$version" ]] || { print -u2 "--version is required."; exit 2; }
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$' ]] || { print -u2 "Invalid version: $version"; exit 2; }
[[ "$architecture_mode" == native || "$architecture_mode" == universal ]] || { print -u2 "Architectures must be native or universal."; exit 2; }
if [[ -n "$sparkle_private_key" && ! -f "$sparkle_private_key" ]]; then
  print -u2 "Sparkle private key does not exist: $sparkle_private_key"
  exit 2
fi

if $unsigned; then
  sign_identity=""
  notarize=false
fi
if $notarize && [[ -z "$sign_identity" || -z "$notary_profile" ]]; then
  print -u2 "--notarize requires --sign-identity and --notary-profile (or matching DERIVED_* variables)."
  exit 2
fi

typeset -a architectures
if [[ "$architecture_mode" == universal ]]; then
  architectures=(arm64 x86_64)
else
  architectures=("$(uname -m)")
fi

print "Derived release $version"
print "Architectures: ${architectures[*]}"
print "Signing: ${sign_identity:-disabled}"
print "Notarization: $notarize"
print "Output: $output_dir"
if $dry_run; then
  print "Dry run complete. No files were changed."
  exit 0
fi

readonly dmgbuild_bin="${DMGBUILD_BIN:-$(command -v dmgbuild || true)}"
if [[ -z "$dmgbuild_bin" || ! -x "$dmgbuild_bin" ]]; then
  print -u2 "dmgbuild 1.6.7 or newer is required to create deterministic Finder metadata."
  print -u2 "Install it with: python3 -m pip install 'dmgbuild>=1.6.7,<2'"
  exit 1
fi

readonly work_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-release.XXXXXX")"
mounted_device=""
function cleanup_work_root {
  if [[ -n "$mounted_device" ]]; then
    hdiutil detach "$mounted_device" -quiet >/dev/null 2>&1 || true
  fi
  if $keep_work; then
    print "Retained build directory: $work_root"
  else
    rm -rf "$work_root"
  fi
}
trap cleanup_work_root EXIT

cd "$project_root"
mkdir -p "$output_dir" "$work_root/bin"

typeset -a cli_slices mcp_slices
for architecture in "${architectures[@]}"; do
  scratch_path="$work_root/swift-$architecture"
  triple="$architecture-apple-macosx14.0"
  swift build -c release --triple "$triple" --scratch-path "$scratch_path"
  bin_path="$(swift build -c release --triple "$triple" --scratch-path "$scratch_path" --show-bin-path)"
  cli_slices+=("$bin_path/derived")
  mcp_slices+=("$bin_path/derived-mcp")
done

if (( ${#architectures} == 1 )); then
  cp "$cli_slices[1]" "$work_root/bin/derived"
  cp "$mcp_slices[1]" "$work_root/bin/derived-mcp"
else
  lipo -create "${cli_slices[@]}" -output "$work_root/bin/derived"
  lipo -create "${mcp_slices[@]}" -output "$work_root/bin/derived-mcp"
fi
chmod 755 "$work_root/bin/derived" "$work_root/bin/derived-mcp"

app_derived_data="$work_root/xcode"
typeset -a app_signing_settings
if [[ -n "$sign_identity" ]]; then
  app_signing_settings=(
    CODE_SIGNING_ALLOWED=YES
    CODE_SIGNING_REQUIRED=YES
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$sign_identity"
  )
else
  app_signing_settings=(CODE_SIGNING_ALLOWED=NO)
fi
xcodebuild -quiet \
  -project Derived.xcodeproj \
  -scheme Derived \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$app_derived_data" \
  ARCHS="${architectures[*]}" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="${version%%-*}" \
  "${app_signing_settings[@]}" \
  build

readonly app_path="$app_derived_data/Build/Products/Release/Derived.app"
[[ -d "$app_path" ]] || { print -u2 "Derived.app was not produced at $app_path"; exit 1; }

for binary in "$work_root/bin/derived" "$work_root/bin/derived-mcp"; do
  actual_architectures="$(lipo -archs "$binary")"
  for architecture in "${architectures[@]}"; do
    [[ " $actual_architectures " == *" $architecture "* ]] || { print -u2 "$binary is missing $architecture"; exit 1; }
  done
done
app_architectures="$(lipo -archs "$app_path/Contents/MacOS/Derived")"
for architecture in "${architectures[@]}"; do
  [[ " $app_architectures " == *" $architecture "* ]] || { print -u2 "Derived.app is missing $architecture"; exit 1; }
done

if [[ -n "$sign_identity" ]]; then
  for binary in "$work_root/bin/derived" "$work_root/bin/derived-mcp"; do
    codesign --force --options runtime --timestamp --sign "$sign_identity" "$binary"
    codesign --verify --strict --verbose=2 "$binary"
  done
  codesign --verify --deep --strict --verbose=2 "$app_path"
fi

readonly installer_path="$work_root/Derived Agent Tools.app"
typeset -a installer_arguments=(
  --version "$version"
  --output "$installer_path"
  --cli "$work_root/bin/derived"
  --mcp "$work_root/bin/derived-mcp"
  --icon "$app_path/Contents/Resources/AppIcon.icns"
  --architectures "${architectures[@]}"
)
if [[ -n "$sign_identity" ]]; then
  installer_arguments+=(--sign-identity "$sign_identity")
fi
scripts/build-agent-tools-installer.sh "${installer_arguments[@]}"

readonly volume_root="$work_root/volume"
mkdir -p "$volume_root/.agent-tools/bin" "$volume_root/.agent-tools/Integrations"
ditto "$app_path" "$volume_root/Derived.app"
ditto "$installer_path" "$volume_root/Derived Agent Tools.app"
ln -s /Applications "$volume_root/Applications"
cp "$work_root/bin/derived" "$work_root/bin/derived-mcp" "$volume_root/.agent-tools/bin/"
ditto Integrations/derived-cleanup "$volume_root/.agent-tools/Integrations/derived-cleanup"
cp docs/AGENT_INTEGRATIONS.md "$volume_root/.agent-tools/AGENT_INTEGRATIONS.md"
cp LICENSE "$volume_root/.agent-tools/LICENSE"
cp scripts/install-codex-agent-tools.sh scripts/uninstall-codex-agent-tools.sh "$volume_root/.agent-tools/"
chmod 755 "$volume_root/.agent-tools"/*.sh
readonly background_path="$work_root/Derived-DMG-Background.png"
readonly background_2x_path="$work_root/Derived-DMG-Background@2x.png"
xcrun swift scripts/generate-dmg-background.swift \
  "$background_path" \
  1
xcrun swift scripts/generate-dmg-background.swift \
  "$background_2x_path" \
  2

readonly artifact_name="Derived-${version}-macOS-${architecture_mode}.dmg"
readonly dmg_path="$output_dir/$artifact_name"
rm -f "$dmg_path" "$dmg_path.sha256"
"$dmgbuild_bin" \
  -s scripts/dmgbuild-settings.py \
  -D "source_root=$volume_root" \
  -D "background=$background_path" \
  -D "volume_icon=$app_path/Contents/Resources/AppIcon.icns" \
  "Derived" \
  "$dmg_path"
hdiutil verify "$dmg_path"

if [[ -n "$sign_identity" ]]; then
  codesign --force --timestamp --sign "$sign_identity" "$dmg_path"
  codesign --verify --strict --verbose=2 "$dmg_path"
fi

if $notarize; then
  typeset -a notary_auth=(--keychain-profile "$notary_profile")
  if [[ -n "$notary_keychain" ]]; then
    notary_auth+=(--keychain "$notary_keychain")
  fi
  xcrun notarytool submit "$dmg_path" "${notary_auth[@]}" --wait
  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
  xcrun stapler staple "$app_path"
  xcrun stapler validate "$app_path"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
fi

(
  cd "$output_dir"
  shasum -a 256 "$artifact_name" > "$artifact_name.sha256"
)
scripts/verify-portable-checksums.sh "$dmg_path.sha256"

if [[ -n "$sparkle_private_key" ]]; then
  readonly generate_appcast="$(find "$app_derived_data/SourcePackages/artifacts" -path '*/bin/generate_appcast' -type f -perm -111 -print -quit)"
  [[ -x "$generate_appcast" ]] || { print -u2 "Sparkle generate_appcast was not found in the resolved package."; exit 1; }
  readonly appcast_root="$work_root/appcast"
  readonly sparkle_output="$output_dir/sparkle"
  readonly sparkle_archive_name="Derived-${version}-macOS-${architecture_mode}.zip"
  mkdir -p "$appcast_root"
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$appcast_root/$sparkle_archive_name"
  "$generate_appcast" \
    --ed-key-file "$sparkle_private_key" \
    --download-url-prefix "https://adiaz0511.github.io/Derived/" \
    --link "https://github.com/adiaz0511/Derived" \
    --maximum-deltas 0 \
    -o "$appcast_root/appcast.xml" \
    "$appcast_root"
  rm -rf "$sparkle_output"
  mkdir -p "$sparkle_output"
  cp "$appcast_root/appcast.xml" "$appcast_root/$sparkle_archive_name" "$sparkle_output/"
  print "Created $sparkle_output/appcast.xml"
  print "Created $sparkle_output/$sparkle_archive_name"
fi

if [[ "$architecture_mode" == native ]]; then
  readonly mcp_architecture_label="$architectures[1]"
else
  readonly mcp_architecture_label="$architecture_mode"
fi
DERIVED_MCP_BINARY="$work_root/bin/derived-mcp" \
DERIVED_MCP_ARCHITECTURE="$mcp_architecture_label" \
  scripts/package-mcpb.sh "$version"
print "Created $dmg_path"
print "Created $dmg_path.sha256"

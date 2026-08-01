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
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

[[ -n "$version" ]] || { print -u2 "--version is required."; exit 2; }
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$' ]] || { print -u2 "Invalid version: $version"; exit 2; }
[[ "$architecture_mode" == native || "$architecture_mode" == universal ]] || { print -u2 "Architectures must be native or universal."; exit 2; }

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

readonly work_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-release.XXXXXX")"
function cleanup_work_root {
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
  triple="$architecture-apple-macosx26.4"
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
xcodebuild -quiet \
  -project Derived.xcodeproj \
  -scheme Derived \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$app_derived_data" \
  ARCHS="${architectures[*]}" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$version" \
  CODE_SIGNING_ALLOWED=NO \
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
  codesign --force --options runtime --timestamp --sign "$sign_identity" "$app_path"
  codesign --verify --deep --strict --verbose=2 "$app_path"
fi

readonly volume_root="$work_root/volume"
mkdir -p "$volume_root/Agent Tools/bin" "$volume_root/Agent Tools/Integrations"
ditto "$app_path" "$volume_root/Derived.app"
ln -s /Applications "$volume_root/Applications"
cp "$work_root/bin/derived" "$work_root/bin/derived-mcp" "$volume_root/Agent Tools/bin/"
ditto Integrations/derived-cleanup "$volume_root/Agent Tools/Integrations/derived-cleanup"
cp docs/AGENT_INTEGRATIONS.md "$volume_root/Agent Tools/AGENT_INTEGRATIONS.md"
cp LICENSE "$volume_root/Agent Tools/LICENSE"
cp "scripts/Install Derived Agent Tools.command" "scripts/Uninstall Derived Agent Tools.command" release/*.html "$volume_root/"
cp scripts/install-codex-agent-tools.sh scripts/uninstall-codex-agent-tools.sh "$volume_root/Agent Tools/"
chmod 755 "$volume_root"/*.command

readonly artifact_name="Derived-${version}-macOS-${architecture_mode}.dmg"
readonly dmg_path="$output_dir/$artifact_name"
rm -f "$dmg_path" "$dmg_path.sha256"
hdiutil create -quiet -fs HFS+ -volname "Derived" -srcfolder "$volume_root" -format UDZO "$dmg_path"
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
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
fi

shasum -a 256 "$dmg_path" > "$dmg_path.sha256"
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

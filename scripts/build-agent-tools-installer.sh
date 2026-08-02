#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
version=""
output_path=""
cli_path=""
mcp_path=""
icon_path=""
sign_identity=""
typeset -a architectures

function usage {
  print -r -- "Usage: scripts/build-agent-tools-installer.sh --version VERSION --output PATH --cli PATH --mcp PATH --icon PATH --architectures ARCH [ARCH ...] [--sign-identity NAME]"
}

while (( $# > 0 )); do
  case "$1" in
    --version) version="${2:?Missing value for --version}"; shift 2 ;;
    --output) output_path="${2:A}"; shift 2 ;;
    --cli) cli_path="${2:A}"; shift 2 ;;
    --mcp) mcp_path="${2:A}"; shift 2 ;;
    --icon) icon_path="${2:A}"; shift 2 ;;
    --architectures)
      shift
      while (( $# > 0 )) && [[ "$1" != --* ]]; do
        architectures+=("$1")
        shift
      done
      ;;
    --sign-identity) sign_identity="${2:?Missing value for --sign-identity}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

[[ -n "$version" ]] || { print -u2 "--version is required."; exit 2; }
[[ -n "$output_path" ]] || { print -u2 "--output is required."; exit 2; }
[[ -x "$cli_path" ]] || { print -u2 "Derived CLI is missing or not executable: $cli_path"; exit 1; }
[[ -x "$mcp_path" ]] || { print -u2 "Derived MCP server is missing or not executable: $mcp_path"; exit 1; }
[[ -f "$icon_path" ]] || { print -u2 "Installer icon is missing: $icon_path"; exit 1; }
(( ${#architectures} > 0 )) || { print -u2 "At least one architecture is required."; exit 2; }

readonly work_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-agent-tools-app.XXXXXX")"
function cleanup_work_root {
  /bin/rm -rf "$work_root"
}
trap cleanup_work_root EXIT

readonly source_root="$project_root/Tools/DerivedAgentToolsInstaller"
readonly sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
typeset -a executable_slices

for architecture in "${architectures[@]}"; do
  slice_path="$work_root/Derived-Agent-Tools-$architecture"
  swiftc \
    -O \
    -target "$architecture-apple-macosx14.0" \
    -sdk "$sdk_path" \
    "$source_root/AppMain.swift" \
    "$source_root/InstallerAppDelegate.swift" \
    -o "$slice_path"
  executable_slices+=("$slice_path")
done

readonly contents_path="$output_path/Contents"
readonly executable_path="$contents_path/MacOS/Derived Agent Tools"
readonly resources_path="$contents_path/Resources"
readonly payload_path="$resources_path/Agent Tools"

/bin/rm -rf "$output_path"
/bin/mkdir -p "$contents_path/MacOS" "$payload_path/bin" "$payload_path/Integrations"

if (( ${#executable_slices} == 1 )); then
  /bin/cp "$executable_slices[1]" "$executable_path"
else
  /usr/bin/lipo -create "${executable_slices[@]}" -output "$executable_path"
fi
/bin/chmod 755 "$executable_path"

/bin/cp "$source_root/Info.plist" "$contents_path/Info.plist"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$version" "$contents_path/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "${version%%-*}" "$contents_path/Info.plist"

/bin/cp "$icon_path" "$resources_path/AppIcon.icns"
/bin/cp "$cli_path" "$mcp_path" "$payload_path/bin/"
/bin/cp \
  "$project_root/scripts/install-codex-agent-tools.sh" \
  "$project_root/scripts/uninstall-codex-agent-tools.sh" \
  "$payload_path/"
/bin/chmod 755 "$payload_path/install-codex-agent-tools.sh" "$payload_path/uninstall-codex-agent-tools.sh"
/usr/bin/ditto \
  "$project_root/Integrations/derived-cleanup" \
  "$payload_path/Integrations/derived-cleanup"
/bin/cp "$project_root/docs/AGENT_INTEGRATIONS.md" "$payload_path/AGENT_INTEGRATIONS.md"
/bin/cp "$project_root/LICENSE" "$payload_path/LICENSE"

actual_architectures="$(/usr/bin/lipo -archs "$executable_path")"
for architecture in "${architectures[@]}"; do
  [[ " $actual_architectures " == *" $architecture "* ]] || {
    print -u2 "Installer executable is missing $architecture."
    exit 1
  }
done

# Local source files can carry provenance or quarantine attributes that cannot
# be copied to the release image. Distribution artifacts must not retain them.
/usr/bin/xattr -cr "$output_path"

if [[ -n "$sign_identity" ]]; then
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$sign_identity" \
    "$output_path"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$output_path"
fi

/usr/bin/plutil -lint "$contents_path/Info.plist"
print "Created $output_path"

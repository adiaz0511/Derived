#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly expected_version="${1:-0.2.0}"
readonly architecture="${DERIVED_MCP_ARCHITECTURE:-$(uname -m)}"
readonly staging_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-mcpb.XXXXXX")"

function cleanup_staging_root {
  rm -rf "$staging_root"
}

trap cleanup_staging_root EXIT
cd "$project_root"

if [[ -n "${DERIVED_MCP_BINARY:-}" ]]; then
  readonly binary="${DERIVED_MCP_BINARY:A}"
  [[ -x "$binary" ]] || { print -u2 "Derived MCP binary is not executable: $binary"; exit 1; }
else
  swift build -c release --product derived-mcp
  readonly binary="$project_root/.build/release/derived-mcp"
fi
readonly manifest="$project_root/Integrations/mcpb/manifest.json"
readonly manifest_version="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest")"

if [[ "$manifest_version" != "$expected_version" ]]; then
  print -u2 "MCPB manifest version $manifest_version does not match requested version $expected_version."
  exit 1
fi

readonly bundle_name="Derived-MCP-${expected_version}-macOS-${architecture}.mcpb"
readonly bundle_root="$staging_root/bundle"
readonly output="$project_root/dist/$bundle_name"

mkdir -p "$bundle_root/server" "$project_root/dist"
cp "$manifest" "$bundle_root/manifest.json"
cp "$project_root/Integrations/mcpb/icon.png" "$bundle_root/icon.png"
cp "$project_root/LICENSE" "$bundle_root/LICENSE"
cp "$binary" "$bundle_root/server/derived-mcp"
chmod 755 "$bundle_root/server/derived-mcp"
rm -f "$output" "$output.sha256"

(
  cd "$bundle_root"
  /usr/bin/zip -q -r "$output" .
)

/usr/bin/shasum -a 256 "$output" > "$output.sha256"
readonly archive_hash="$(/usr/bin/shasum -a 256 "$output" | /usr/bin/awk '{print $1}')"
readonly registry_output="$project_root/dist/server.json"
/usr/bin/python3 - "$project_root/server.json" "$registry_output" "$expected_version" "$bundle_name" "$archive_hash" <<'PY'
import json
import sys

source, destination, version, bundle_name, archive_hash = sys.argv[1:]
with open(source, encoding="utf-8") as handle:
    metadata = json.load(handle)

metadata["version"] = version
package = metadata["packages"][0]
package["identifier"] = (
    f"https://github.com/adiaz0511/Derived/releases/download/v{version}/{bundle_name}"
)
package["fileSha256"] = archive_hash

with open(destination, "w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2)
    handle.write("\n")
PY
print "Created dist/$bundle_name"
print "Created dist/server.json"

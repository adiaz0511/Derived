#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly expected_version="${1:-}"
readonly architecture="$(uname -m)"
readonly staging_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-agent-tools.XXXXXX")"

function cleanup_staging_root {
  rm -rf "$staging_root"
}

trap cleanup_staging_root EXIT
cd "$project_root"

swift build -c release
readonly derived_binary="$project_root/.build/release/derived"
readonly version_output="$("$derived_binary" --version)"

if [[ "$version_output" != "derived "* ]]; then
  print -u2 "Unable to read the release version from: $version_output"
  exit 1
fi

readonly version="${version_output#derived }"
if [[ -n "$expected_version" && "$expected_version" != "$version" ]]; then
  print -u2 "Requested package version $expected_version does not match binary version $version."
  exit 1
fi

readonly archive_name="DerivedAgentTools-${version}-macOS-${architecture}"
readonly archive_root="$staging_root/$archive_name"

mkdir -p "$archive_root/bin" "$archive_root/Integrations"
cp "$derived_binary" "$archive_root/bin/derived"
cp .build/release/derived-mcp "$archive_root/bin/derived-mcp"
cp -R Integrations/derived-cleanup "$archive_root/Integrations/derived-cleanup"
cp docs/AGENT_INTEGRATIONS.md "$archive_root/AGENT_INTEGRATIONS.md"
cp LICENSE "$archive_root/LICENSE"

mkdir -p dist
tar -C "$staging_root" -czf "dist/$archive_name.tar.gz" "$archive_name"
shasum -a 256 "dist/$archive_name.tar.gz" > "dist/$archive_name.tar.gz.sha256"

print "Created dist/$archive_name.tar.gz from Derived agent tools $version"

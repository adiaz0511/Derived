#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly checksum_test_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-checksum-test.XXXXXX")"

function cleanup_checksum_test_root {
  rm -rf "$checksum_test_root"
}

trap cleanup_checksum_test_root EXIT
cd "$project_root"

/usr/bin/diff -qr \
  Integrations/derived-cleanup \
  Integrations/codex-plugin/derived/skills/derived-cleanup

[[ -x Integrations/codex-plugin/derived/scripts/launch-derived-mcp ]]
[[ -f Integrations/derived-cleanup/assets/icon-small.png ]]
[[ -f Integrations/derived-cleanup/assets/icon-large.png ]]
/usr/bin/grep -q 'icon_small: "./assets/icon-small.png"' \
  Integrations/derived-cleanup/agents/openai.yaml
/usr/bin/grep -q 'icon_large: "./assets/icon-large.png"' \
  Integrations/derived-cleanup/agents/openai.yaml

/usr/bin/python3 <<'PY'
import json
import re
from pathlib import Path

plugin = json.loads(Path("Integrations/codex-plugin/derived/.codex-plugin/plugin.json").read_text())
assert plugin["name"] == "derived"
assert plugin["version"] == "1.0.2"
assert plugin["skills"] == "./skills/"
assert plugin["mcpServers"] == "./.mcp.json"
assert plugin["interface"]["composerIcon"] == "./assets/derived-app-icon.png"

mcp_config = json.loads(Path("Integrations/codex-plugin/derived/.mcp.json").read_text())
assert mcp_config["mcpServers"]["derived"]["command"] == "./scripts/launch-derived-mcp"

manifest = json.loads(Path("Integrations/mcpb/manifest.json").read_text())
assert manifest["name"] == "derived-mcp"
assert manifest["version"] == "1.0.2"
assert manifest["server"]["type"] == "binary"
assert manifest["server"]["entry_point"] == "server/derived-mcp"

server = json.loads(Path("server.json").read_text())
assert server["name"] == "io.github.adiaz0511/derived"
assert server["version"] == "1.0.2"
package = server["packages"][0]
assert package["registryType"] == "mcpb"
assert package["transport"]["type"] == "stdio"
assert package["identifier"].endswith(".mcpb")
assert re.fullmatch(r"[0-9a-f]{64}", package["fileSha256"])

workflow = Path(".github/workflows/release.yml").read_text()

def step_block(name):
    match = re.search(
        rf"(?ms)^      - name: {re.escape(name)}\n.*?(?=^      - name: |\Z)",
        workflow,
    )
    assert match, f"Missing release workflow step: {name}"
    return match.group(0)

def block_paths(block, key):
    match = re.search(
        rf"(?m)^          {re.escape(key)}: \|\n((?:            .+\n)+)",
        block,
    )
    assert match, f"Missing multiline {key} block"
    return {
        line.strip()
        for line in match.group(1).splitlines()
        if line.strip()
    }

publish = step_block("Publish GitHub release")
assert block_paths(publish, "files") == {"dist/*.dmg", "dist/*.mcpb"}

registry_metadata = step_block("Preserve MCP Registry metadata")
assert "if: github.event_name == 'push'" in registry_metadata
assert "uses: actions/upload-artifact@v4" in registry_metadata
assert "path: dist/server.json" in registry_metadata

manual = step_block("Upload manual validation artifact")
assert block_paths(manual, "path") == {
    "dist/*.dmg",
    "dist/*.mcpb",
    "dist/*.sha256",
    "dist/server.json",
}

signed_build = step_block("Build, sign, and notarize release DMG")
assert "--sparkle-private-key" in signed_build

homebrew_checkout = step_block("Check out Homebrew tap")
assert "repository: adiaz0511/homebrew-derived" in homebrew_checkout
assert "ssh-key: ${{ secrets.HOMEBREW_TAP_DEPLOY_KEY }}" in homebrew_checkout

homebrew_update = step_block("Update Homebrew packages")
assert "scripts/update-homebrew-casks.sh" in homebrew_update

appcast_upload = step_block("Upload Sparkle update feed")
assert "uses: actions/upload-pages-artifact@v3" in appcast_upload
assert "uses: actions/configure-pages@v5" in workflow
assert "uses: actions/deploy-pages@v4" in workflow

info_plist = Path("Configuration/Derived-Info.plist").read_text()
assert "https://adiaz0511.github.io/Derived/appcast.xml" in info_plist
assert "SUPublicEDKey" in info_plist
PY

readonly tap_test_root="$checksum_test_root/homebrew-tap"
mkdir -p "$tap_test_root"
scripts/update-homebrew-casks.sh \
  --version 9.8.7 \
  --sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef \
  --tap-root "$tap_test_root" >/dev/null
for cask in derived derived-tools; do
  /usr/bin/grep -q 'version "9.8.7"' "$tap_test_root/Casks/$cask.rb"
  /usr/bin/grep -q 'sha256 "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' "$tap_test_root/Casks/$cask.rb"
  /usr/bin/ruby -c "$tap_test_root/Casks/$cask.rb" >/dev/null
done

readonly test_artifact="$checksum_test_root/Derived-test.mcpb"
readonly test_checksum="$test_artifact.sha256"
print -n "portable checksum fixture" > "$test_artifact"
(
  cd "$checksum_test_root"
  /usr/bin/shasum -a 256 "${test_artifact:t}" > "${test_checksum:t}"
)
scripts/verify-portable-checksums.sh "$test_checksum" >/dev/null

/usr/bin/shasum -a 256 "$test_artifact" > "$test_checksum"
if scripts/verify-portable-checksums.sh "$test_checksum" >/dev/null 2>&1; then
  print -u2 "Absolute artifact paths must be rejected in checksum files."
  exit 1
fi

print "Skill, plugin, MCPB, and MCP Registry metadata tests passed."

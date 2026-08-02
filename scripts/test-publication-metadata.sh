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
assert plugin["version"] == "1.0.1"
assert plugin["skills"] == "./skills/"
assert plugin["mcpServers"] == "./.mcp.json"
assert plugin["interface"]["composerIcon"] == "./assets/derived-app-icon.png"

mcp_config = json.loads(Path("Integrations/codex-plugin/derived/.mcp.json").read_text())
assert mcp_config["mcpServers"]["derived"]["command"] == "./scripts/launch-derived-mcp"

manifest = json.loads(Path("Integrations/mcpb/manifest.json").read_text())
assert manifest["name"] == "derived-mcp"
assert manifest["version"] == "1.0.1"
assert manifest["server"]["type"] == "binary"
assert manifest["server"]["entry_point"] == "server/derived-mcp"

server = json.loads(Path("server.json").read_text())
assert server["name"] == "io.github.adiaz0511/derived"
assert server["version"] == "1.0.1"
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
PY

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

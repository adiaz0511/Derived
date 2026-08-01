#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
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
assert plugin["version"] == "0.2.0"
assert plugin["skills"] == "./skills/"
assert plugin["mcpServers"] == "./.mcp.json"
assert plugin["interface"]["composerIcon"] == "./assets/derived-app-icon.png"

mcp_config = json.loads(Path("Integrations/codex-plugin/derived/.mcp.json").read_text())
assert mcp_config["mcpServers"]["derived"]["command"] == "./scripts/launch-derived-mcp"

manifest = json.loads(Path("Integrations/mcpb/manifest.json").read_text())
assert manifest["name"] == "derived-mcp"
assert manifest["version"] == "0.2.0"
assert manifest["server"]["type"] == "binary"
assert manifest["server"]["entry_point"] == "server/derived-mcp"

server = json.loads(Path("server.json").read_text())
assert server["name"] == "io.github.adiaz0511/derived"
assert server["version"] == "0.2.0"
package = server["packages"][0]
assert package["registryType"] == "mcpb"
assert package["transport"]["type"] == "stdio"
assert package["identifier"].endswith(".mcpb")
assert re.fullmatch(r"[0-9a-f]{64}", package["fileSha256"])
PY

print "Skill, plugin, MCPB, and MCP Registry metadata tests passed."

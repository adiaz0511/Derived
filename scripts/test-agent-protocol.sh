#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly build_path="$project_root/.build/debug"
readonly output_file="${TMPDIR:-/tmp}/derived-mcp-smoke-$RANDOM.jsonl"

cd "$project_root"
swift build

"$build_path/derived" --help | /usr/bin/grep -q "Derived command-line interface"
[[ "$("$build_path/derived" --version)" == "derived 1.0.0" ]]
/usr/bin/grep -q "Prefer MCP and CLI access over the Derived macOS UI or Computer Use" "$project_root/Integrations/derived-cleanup/SKILL.md"
/usr/bin/grep -q 'plugin://computer-use' "$project_root/Integrations/derived-cleanup/SKILL.md"
/usr/bin/grep -q 'Use \$derived-cleanup' "$project_root/Integrations/derived-cleanup/agents/openai.yaml"
/usr/bin/grep -q 'current CLI and MCP agent-tools version is `1.0.0`' "$project_root/README.md"
/usr/bin/grep -q 'derived scan --json' "$project_root/README.md"
/usr/bin/grep -q 'scripts/install-codex-agent-tools.sh' "$project_root/README.md"
/usr/bin/grep -q 'DerivedCLITests' "$project_root/README.md"
/usr/bin/grep -q 'current agent-tools version is `1.0.0`' "$project_root/docs/AGENT_INTEGRATIONS.md"
/usr/bin/grep -q 'scan output includes a totals row' "$project_root/docs/AGENT_INTEGRATIONS.md"
/usr/bin/grep -q 'derived --version' "$project_root/Integrations/derived-cleanup/references/tools.md"

printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_candidates","arguments":{"scan_id":"00000000-0000-0000-0000-000000000000","category":"derivedData"}}}' \
  | "$build_path/derived-mcp" > "$output_file"

python3 - "$output_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    messages = [json.loads(line) for line in handle if line.strip()]

assert len(messages) == 3
assert messages[0]["result"]["protocolVersion"] == "2025-06-18"
assert messages[0]["result"]["serverInfo"]["name"] == "derived"
assert messages[0]["result"]["serverInfo"]["version"] == "1.0.0"

tools = {tool["name"]: tool for tool in messages[1]["result"]["tools"]}
assert set(tools) == {"scan", "list_candidates", "prepare_cleanup", "execute_cleanup"}
assert tools["scan"]["annotations"]["readOnlyHint"] is True
assert tools["execute_cleanup"]["annotations"]["destructiveHint"] is True
assert messages[2]["result"]["isError"] is True
PY

rm -f "$output_file"

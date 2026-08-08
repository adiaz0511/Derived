#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly test_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-agent-tools-update.XXXXXX")"
function cleanup_test_root {
  /bin/rm -rf "$test_root"
}
trap cleanup_test_root EXIT

readonly test_home="$test_root/home"
readonly payload_root="$test_root/payload"
readonly install_bin="$test_home/.local/bin"
readonly installed_skill="$test_home/.codex/skills/derived-cleanup"
/bin/mkdir -p "$payload_root/bin" "$payload_root/Integrations/derived-cleanup" \
  "$install_bin" "$installed_skill"

printf '#!/bin/zsh\nprint "derived 1.0.6"\n' > "$payload_root/bin/derived"
printf '#!/bin/zsh\nprint "derived 1.0.6"\n' > "$payload_root/bin/derived-mcp"
printf '#!/bin/zsh\nprint "derived 1.0.4"\n' > "$install_bin/derived"
printf '#!/bin/zsh\nprint "derived 1.0.4"\n' > "$install_bin/derived-mcp"
printf 'new skill\n' > "$payload_root/Integrations/derived-cleanup/SKILL.md"
printf 'old skill\n' > "$installed_skill/SKILL.md"
/bin/chmod 755 "$payload_root/bin/derived" "$payload_root/bin/derived-mcp" \
  "$install_bin/derived" "$install_bin/derived-mcp"

HOME="$test_home" \
DERIVED_AGENT_TOOLS_SOURCE_DIR="$payload_root" \
  "$project_root/scripts/update-agent-tools.sh" > "$test_root/output.txt"

[[ "$("$install_bin/derived" --version)" == "derived 1.0.6" ]]
[[ "$(<"$installed_skill/SKILL.md")" == "new skill" ]]
/usr/bin/grep -q 'Refreshed integrations for: Codex' "$test_root/output.txt"

print "Agent Tools update test passed."

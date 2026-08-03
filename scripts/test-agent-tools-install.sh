#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly test_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-agent-tools-test.XXXXXX")"

function cleanup_test_root {
  /bin/rm -rf "$test_root"
}
trap cleanup_test_root EXIT

readonly dmg_root="$test_root/Derived"
readonly payload_root="$dmg_root/Agent Tools"
readonly test_home="$test_root/home"
readonly test_bin="$test_home/.local/bin"
readonly test_codex_root="$test_home/.codex"
readonly fake_codex="$test_root/codex"
readonly fake_codex_state="$test_root/codex-state"
readonly fake_codex_log="$test_root/codex-log"

mkdir -p "$payload_root/bin" "$payload_root/Integrations" \
  "$test_codex_root/skills/unrelated-skill" "$test_home/Library/Application Support/Derived"

/bin/cp "$project_root/scripts/install-codex-agent-tools.sh" "$payload_root/install-codex-agent-tools.sh"
/bin/cp "$project_root/scripts/uninstall-codex-agent-tools.sh" "$payload_root/uninstall-codex-agent-tools.sh"
/bin/chmod 755 "$payload_root/install-codex-agent-tools.sh" \
  "$payload_root/uninstall-codex-agent-tools.sh"

/bin/cp -R "$project_root/Integrations/derived-cleanup" \
  "$payload_root/Integrations/derived-cleanup"

print -r -- '#!/bin/zsh' > "$payload_root/bin/derived"
print -r -- '[[ "${1:-}" == "--version" ]] && print "derived 1.0.4"' >> "$payload_root/bin/derived"
print -r -- '#!/bin/zsh' > "$payload_root/bin/derived-mcp"
print -r -- 'exit 0' >> "$payload_root/bin/derived-mcp"
chmod 755 "$payload_root/bin/derived" "$payload_root/bin/derived-mcp"

print -r -- '#!/bin/zsh' > "$fake_codex"
print -r -- 'print -r -- "$*" >> "$FAKE_CODEX_LOG"' >> "$fake_codex"
print -r -- 'if [[ "$1 $2" == "mcp get" ]]; then' >> "$fake_codex"
print -r -- '  [[ -f "$FAKE_CODEX_STATE" ]]' >> "$fake_codex"
print -r -- 'elif [[ "$1 $2" == "mcp remove" ]]; then' >> "$fake_codex"
print -r -- '  /bin/rm -f "$FAKE_CODEX_STATE"' >> "$fake_codex"
print -r -- 'elif [[ "$1 $2" == "mcp add" ]]; then' >> "$fake_codex"
print -r -- '  [[ "${FAKE_CODEX_FAIL_ADD:-no}" != "yes" ]] || exit 1' >> "$fake_codex"
print -r -- '  : > "$FAKE_CODEX_STATE"' >> "$fake_codex"
print -r -- 'else' >> "$fake_codex"
print -r -- '  exit 2' >> "$fake_codex"
print -r -- 'fi' >> "$fake_codex"
chmod 755 "$fake_codex"

: > "$fake_codex_state"
print -r -- 'keep' > "$test_codex_root/skills/unrelated-skill/SKILL.md"
print -r -- 'keep' > "$test_home/Library/Application Support/Derived/history.jsonl"

HOME="$test_home" \
CODEX_HOME="$test_codex_root" \
DERIVED_INSTALL_BIN_DIR="$test_bin" \
DERIVED_CODEX_CLI="$fake_codex" \
FAKE_CODEX_STATE="$fake_codex_state" \
FAKE_CODEX_LOG="$fake_codex_log" \
  /bin/zsh "$payload_root/install-codex-agent-tools.sh" >/dev/null

[[ "$($test_bin/derived --version)" == "derived 1.0.4" ]]
[[ -x "$test_bin/derived-mcp" ]]
[[ -f "$test_codex_root/skills/derived-cleanup/SKILL.md" ]]
[[ -f "$test_codex_root/skills/unrelated-skill/SKILL.md" ]]
/usr/bin/grep -q '^mcp remove derived$' "$fake_codex_log"
/usr/bin/grep -q "^mcp add derived -- $test_bin/derived-mcp$" "$fake_codex_log"

HOME="$test_home" \
CODEX_HOME="$test_codex_root" \
DERIVED_INSTALL_BIN_DIR="$test_bin" \
DERIVED_CODEX_CLI="$fake_codex" \
FAKE_CODEX_STATE="$fake_codex_state" \
FAKE_CODEX_LOG="$fake_codex_log" \
  /bin/zsh "$payload_root/uninstall-codex-agent-tools.sh" >/dev/null

[[ ! -e "$test_bin/derived" ]]
[[ ! -e "$test_bin/derived-mcp" ]]
[[ ! -e "$test_codex_root/skills/derived-cleanup" ]]
[[ ! -e "$fake_codex_state" ]]
[[ -f "$test_codex_root/skills/unrelated-skill/SKILL.md" ]]
[[ -f "$test_home/Library/Application Support/Derived/history.jsonl" ]]

mkdir -p "$test_bin" "$test_codex_root/skills/derived-cleanup"
print -r -- 'previous-cli' > "$test_bin/derived"
print -r -- 'previous-mcp' > "$test_bin/derived-mcp"
print -r -- 'previous-skill' > "$test_codex_root/skills/derived-cleanup/SKILL.md"
print -r -- 'previous-config' > "$test_codex_root/config.toml"

if HOME="$test_home" \
  CODEX_HOME="$test_codex_root" \
  DERIVED_INSTALL_BIN_DIR="$test_bin" \
  DERIVED_CODEX_CLI="$fake_codex" \
  FAKE_CODEX_STATE="$fake_codex_state" \
  FAKE_CODEX_LOG="$fake_codex_log" \
  FAKE_CODEX_FAIL_ADD=yes \
    /bin/zsh "$payload_root/install-codex-agent-tools.sh" >/dev/null 2>&1; then
  print -u2 "Installer unexpectedly succeeded when MCP registration failed."
  exit 1
fi

[[ "$(<"$test_bin/derived")" == "previous-cli" ]]
[[ "$(<"$test_bin/derived-mcp")" == "previous-mcp" ]]
[[ "$(<"$test_codex_root/skills/derived-cleanup/SKILL.md")" == "previous-skill" ]]
[[ "$(<"$test_codex_root/config.toml")" == "previous-config" ]]

/usr/bin/plutil -lint "$project_root/Tools/DerivedAgentToolsInstaller/Info.plist" >/dev/null
swiftc \
  -typecheck \
  -target "$(uname -m)-apple-macosx14.0" \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  "$project_root/Tools/DerivedAgentToolsInstaller/AppMain.swift" \
  "$project_root/Tools/DerivedAgentToolsInstaller/InstallerAppDelegate.swift"

print "Agent-tools installation and uninstallation tests passed."

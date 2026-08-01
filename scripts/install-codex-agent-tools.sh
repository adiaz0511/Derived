#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
readonly install_bin_dir="${DERIVED_INSTALL_BIN_DIR:-${HOME:?}/.local/bin}"
readonly codex_root="${CODEX_HOME:-${HOME:?}/.codex}"
readonly install_skill_dir="$codex_root/skills/derived-cleanup"

codex_cli="$(command -v codex || true)"
if [[ -z "$codex_cli" ]]; then
  print -u2 "Codex CLI was not found on PATH."
  exit 1
fi
readonly codex_cli

cd "$project_root"
swift build -c release

mkdir -p "$install_bin_dir" "${install_skill_dir:h}"
/usr/bin/install -m 755 .build/release/derived "$install_bin_dir/derived"
/usr/bin/install -m 755 .build/release/derived-mcp "$install_bin_dir/derived-mcp"
/usr/bin/ditto Integrations/derived-cleanup "$install_skill_dir"

if "$codex_cli" mcp get derived >/dev/null 2>&1; then
  "$codex_cli" mcp remove derived
fi
"$codex_cli" mcp add derived -- "$install_bin_dir/derived-mcp"

print "Installed Derived CLI: $install_bin_dir/derived"
print "Installed Derived MCP: $install_bin_dir/derived-mcp"
print "Installed Derived skill: $install_skill_dir"

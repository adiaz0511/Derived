#!/bin/zsh

set -euo pipefail

readonly install_bin_dir="${DERIVED_INSTALL_BIN_DIR:-${HOME:?}/.local/bin}"
readonly codex_root="${CODEX_HOME:-${HOME:?}/.codex}"
readonly install_skill_dir="$codex_root/skills/derived-cleanup"
readonly mcp_name="derived"

function find_codex_cli {
  local candidate

  if [[ -n "${DERIVED_CODEX_CLI:-}" ]]; then
    [[ -x "$DERIVED_CODEX_CLI" ]] || return 1
    print -r -- "$DERIVED_CODEX_CLI"
    return 0
  fi

  candidate="$(command -v codex 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    print -r -- "$candidate"
    return 0
  fi

  for candidate in /opt/homebrew/bin/codex /usr/local/bin/codex "$HOME/.local/bin/codex"; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

codex_cli="$(find_codex_cli || true)"
if [[ -n "$codex_cli" ]] && "$codex_cli" mcp get "$mcp_name" >/dev/null 2>&1; then
  "$codex_cli" mcp remove "$mcp_name" >/dev/null
  print "Removed the Derived MCP registration from Codex."
elif [[ -z "$codex_cli" ]]; then
  print -u2 "Warning: Codex was not found, so its MCP registration was not changed."
fi

/bin/rm -f "$install_bin_dir/derived" "$install_bin_dir/derived-mcp"
/bin/rm -rf "$install_skill_dir"

print "Removed the Derived CLI, MCP executable, and derived-cleanup skill."
print "Derived application data, scan history, and preferences were not removed."

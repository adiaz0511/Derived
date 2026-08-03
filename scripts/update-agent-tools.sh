#!/bin/zsh

set -u

readonly payload_root="${DERIVED_AGENT_TOOLS_SOURCE_DIR:?DERIVED_AGENT_TOOLS_SOURCE_DIR is required}"
readonly install_bin_dir="${DERIVED_INSTALL_BIN_DIR:-${HOME:?}/.local/bin}"
readonly derived_source="$payload_root/bin/derived"
readonly mcp_source="$payload_root/bin/derived-mcp"
readonly skill_source="$payload_root/Integrations/derived-cleanup"

function fail {
  print -u2 "Error: $1"
  exit 1
}

[[ -x "$derived_source" ]] || fail "The bundled Derived CLI is missing."
[[ -x "$mcp_source" ]] || fail "The bundled Derived MCP server is missing."
[[ -f "$skill_source/SKILL.md" ]] || fail "The bundled derived-cleanup skill is missing."
[[ -x "$install_bin_dir/derived" ]] || fail "A DMG-installed Derived CLI was not found in $install_bin_dir."

/bin/mkdir -p "$install_bin_dir" || fail "The Agent Tools directory could not be opened."
readonly staging_root="$(/usr/bin/mktemp -d "$install_bin_dir/.derived-update.XXXXXX")" || fail "A staging directory could not be created."
readonly previous_root="$staging_root/previous"
readonly next_root="$staging_root/next"
/bin/mkdir -p "$previous_root" "$next_root" || fail "The update could not be staged."

function cleanup_staging_root {
  /bin/rm -rf "$staging_root"
}
trap cleanup_staging_root EXIT

/usr/bin/install -m 755 "$derived_source" "$next_root/derived" || fail "The Derived CLI could not be staged."
/usr/bin/install -m 755 "$mcp_source" "$next_root/derived-mcp" || fail "The MCP server could not be staged."
/bin/cp -p "$install_bin_dir/derived" "$previous_root/derived" || fail "The current CLI could not be backed up."

readonly had_mcp=$([[ -e "$install_bin_dir/derived-mcp" ]] && print yes || print no)
if [[ "$had_mcp" == yes ]]; then
  /bin/cp -p "$install_bin_dir/derived-mcp" "$previous_root/derived-mcp" || fail "The current MCP server could not be backed up."
fi

typeset -a client_names client_skill_directories
client_names=(Codex "Claude Code" Cursor)
client_skill_directories=(
  "$HOME/.codex/skills/derived-cleanup"
  "$HOME/.claude/skills/derived-cleanup"
  "$HOME/.cursor/skills/derived-cleanup"
)

typeset -a updated_clients
integer index
for index in {1..3}; do
  destination="${client_skill_directories[$index]}"
  if [[ -f "$destination/SKILL.md" ]]; then
    /usr/bin/ditto "$destination" "$previous_root/skill-$index" || fail "The ${client_names[$index]} skill could not be backed up."
    /usr/bin/ditto "$skill_source" "$next_root/skill-$index" || fail "The ${client_names[$index]} skill could not be staged."
    updated_clients+=("${client_names[$index]}")
  fi
done

function rollback_update {
  /usr/bin/install -m 755 "$previous_root/derived" "$install_bin_dir/derived" >/dev/null 2>&1 || true
  if [[ "$had_mcp" == yes ]]; then
    /usr/bin/install -m 755 "$previous_root/derived-mcp" "$install_bin_dir/derived-mcp" >/dev/null 2>&1 || true
  else
    /bin/rm -f "$install_bin_dir/derived-mcp"
  fi

  for index in {1..3}; do
    destination="${client_skill_directories[$index]}"
    if [[ -d "$previous_root/skill-$index" ]]; then
      /bin/rm -rf "$destination"
      /usr/bin/ditto "$previous_root/skill-$index" "$destination" >/dev/null 2>&1 || true
    fi
  done
}

if ! /bin/mv -f "$next_root/derived" "$install_bin_dir/derived"; then
  rollback_update
  fail "The Derived CLI could not be updated. Your previous installation was restored."
fi
if ! /bin/mv -f "$next_root/derived-mcp" "$install_bin_dir/derived-mcp"; then
  rollback_update
  fail "The MCP server could not be updated. Your previous installation was restored."
fi

for index in {1..3}; do
  destination="${client_skill_directories[$index]}"
  if [[ -d "$next_root/skill-$index" ]]; then
    /bin/rm -rf "$destination"
    if ! /bin/mv "$next_root/skill-$index" "$destination"; then
      rollback_update
      fail "The ${client_names[$index]} skill could not be updated. Your previous installation was restored."
    fi
  fi
done

readonly version_output="$("$install_bin_dir/derived" --version 2>/dev/null)" || {
  rollback_update
  fail "The updated CLI could not be verified. Your previous installation was restored."
}

print -r -- "Updated $version_output."
if (( ${#updated_clients} > 0 )); then
  print -r -- "Refreshed integrations for: ${(j:, :)updated_clients}. Restart these clients before using Derived."
else
  print -r -- "No installed agent skills required an update."
fi

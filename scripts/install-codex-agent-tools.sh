#!/bin/zsh

set -euo pipefail

readonly script_dir="${0:A:h}"
readonly project_root="${script_dir:h}"
readonly install_bin_dir="${DERIVED_INSTALL_BIN_DIR:-${HOME:?}/.local/bin}"
readonly codex_root="${CODEX_HOME:-${HOME:?}/.codex}"
readonly install_skill_dir="$codex_root/skills/derived-cleanup"
readonly mcp_name="derived"

function fail {
  print -u2 "Error: $1"
  exit 1
}

function find_payload_directory {
  local candidate
  local -a candidates

  if [[ -n "${DERIVED_AGENT_TOOLS_SOURCE_DIR:-}" ]]; then
    candidates+=("$DERIVED_AGENT_TOOLS_SOURCE_DIR")
  fi

  candidates+=(
    "$script_dir/Agent Tools"
    "$script_dir"
    "$project_root"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate/bin/derived" && -x "$candidate/bin/derived-mcp" ]]; then
      print -r -- "$candidate"
      return 0
    fi

    if [[ -x "$candidate/.build/release/derived" && -x "$candidate/.build/release/derived-mcp" ]]; then
      print -r -- "$candidate/.build/release"
      return 0
    fi
  done

  return 1
}

function find_skill_source {
  local payload_root="$1"
  local candidate
  local -a candidates=(
    "$payload_root/Integrations/derived-cleanup"
    "$payload_root/derived-cleanup"
    "$script_dir/Agent Tools/Integrations/derived-cleanup"
    "$script_dir/Integrations/derived-cleanup"
    "$project_root/Integrations/derived-cleanup"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate/SKILL.md" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

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

payload_root="$(find_payload_directory)" || fail \
  "The precompiled Derived agent tools were not found. Reopen Derived.dmg and run the installer from the mounted image."
readonly payload_root

if [[ -x "$payload_root/bin/derived" ]]; then
  readonly derived_source="$payload_root/bin/derived"
  readonly mcp_source="$payload_root/bin/derived-mcp"
else
  readonly derived_source="$payload_root/derived"
  readonly mcp_source="$payload_root/derived-mcp"
fi

skill_source="$(find_skill_source "$payload_root")" || fail \
  "The derived-cleanup skill was not found beside the agent tools."
readonly skill_source

codex_cli="$(find_codex_cli)" || fail \
  "The Codex CLI was not found. Install Codex, ensure 'codex' is on PATH, and run this installer again."
readonly codex_cli

version_output="$($derived_source --version 2>/dev/null)" || fail \
  "The bundled Derived CLI could not be executed on this Mac."
[[ "$version_output" == "derived "* ]] || fail \
  "The bundled CLI returned an unexpected version: $version_output"
readonly version_output

mkdir -p "$install_bin_dir" "${install_skill_dir:h}"

readonly staging_root="$(mktemp -d "${TMPDIR:-/tmp}/derived-agent-tools-install.XXXXXX")"
function cleanup_staging_root {
  /bin/rm -rf "$staging_root"
}
trap cleanup_staging_root EXIT

/usr/bin/install -m 755 "$derived_source" "$staging_root/derived"
/usr/bin/install -m 755 "$mcp_source" "$staging_root/derived-mcp"
/usr/bin/ditto "$skill_source" "$staging_root/derived-cleanup"

readonly derived_backup="$staging_root/previous-derived"
readonly mcp_backup="$staging_root/previous-derived-mcp"
readonly had_derived=$([[ -e "$install_bin_dir/derived" ]] && print yes || print no)
readonly had_mcp=$([[ -e "$install_bin_dir/derived-mcp" ]] && print yes || print no)
if [[ "$had_derived" == yes ]]; then
  /bin/cp -p "$install_bin_dir/derived" "$derived_backup"
fi
if [[ "$had_mcp" == yes ]]; then
  /bin/cp -p "$install_bin_dir/derived-mcp" "$mcp_backup"
fi

/bin/mv -f "$staging_root/derived" "$install_bin_dir/derived"
/bin/mv -f "$staging_root/derived-mcp" "$install_bin_dir/derived-mcp"

readonly skill_backup="$staging_root/previous-derived-cleanup"
if [[ -e "$install_skill_dir" || -L "$install_skill_dir" ]]; then
  /bin/mv "$install_skill_dir" "$skill_backup"
fi

function rollback_payload {
  /bin/rm -f "$install_bin_dir/derived" "$install_bin_dir/derived-mcp"
  /bin/rm -rf "$install_skill_dir"
  if [[ "$had_derived" == yes ]]; then
    /bin/mv "$derived_backup" "$install_bin_dir/derived"
  fi
  if [[ "$had_mcp" == yes ]]; then
    /bin/mv "$mcp_backup" "$install_bin_dir/derived-mcp"
  fi
  if [[ -e "$skill_backup" || -L "$skill_backup" ]]; then
    /bin/mv "$skill_backup" "$install_skill_dir"
  fi
}

if ! /bin/mv "$staging_root/derived-cleanup" "$install_skill_dir"; then
  rollback_payload
  fail "The derived-cleanup skill could not be installed."
fi

readonly config_file="$codex_root/config.toml"
readonly config_backup="$staging_root/config.toml"
readonly config_existed=$([[ -f "$config_file" ]] && print yes || print no)
if [[ "$config_existed" == "yes" ]]; then
  /bin/cp "$config_file" "$config_backup"
fi

if "$codex_cli" mcp get "$mcp_name" >/dev/null 2>&1; then
  "$codex_cli" mcp remove "$mcp_name" >/dev/null
fi

if ! "$codex_cli" mcp add "$mcp_name" -- "$install_bin_dir/derived-mcp" >/dev/null; then
  if [[ "$config_existed" == "yes" ]]; then
    /bin/mkdir -p "${config_file:h}"
    /bin/cp "$config_backup" "$config_file"
  else
    /bin/rm -f "$config_file"
  fi
  rollback_payload
  fail "Codex could not register the Derived MCP server. The previous installation and Codex configuration were restored."
fi

print ""
print "Derived agent tools installed successfully."
print ""
print "  CLI:   $install_bin_dir/derived"
print "  MCP:   $install_bin_dir/derived-mcp"
print "  Skill: $install_skill_dir"
print "  Version: $version_output"
print ""
print "Verification:"
print "  $install_bin_dir/derived --version"
print "  codex mcp get derived"
print ""
print "Restart Codex before using the skill."

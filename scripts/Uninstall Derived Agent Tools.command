#!/bin/zsh

set -euo pipefail

readonly script_dir="${0:A:h}"

if [[ -f "$script_dir/Agent Tools/uninstall-codex-agent-tools.sh" ]]; then
  exec /bin/zsh "$script_dir/Agent Tools/uninstall-codex-agent-tools.sh"
fi

exec /bin/zsh "$script_dir/uninstall-codex-agent-tools.sh"

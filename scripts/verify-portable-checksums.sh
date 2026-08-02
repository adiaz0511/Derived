#!/bin/zsh

set -euo pipefail

(( $# > 0 )) || { print -u2 "Provide at least one SHA-256 checksum file."; exit 2; }

function verify_checksum {
  local checksum_argument="$1"
  local checksum_path="${checksum_argument:A}"
  [[ -f "$checksum_path" ]] || { print -u2 "Checksum file not found: $checksum_argument"; exit 1; }

  local checksum_directory="${checksum_path:h}"
  local checksum_name="${checksum_path:t}"
  local artifact_name="${checksum_name%.sha256}"
  local recorded_name="$(/usr/bin/awk 'NR == 1 { print $2 }' "$checksum_path")"

  if [[ "$recorded_name" != "$artifact_name" ]]; then
    print -u2 "$checksum_name must record only $artifact_name, not $recorded_name."
    exit 1
  fi
  [[ -f "$checksum_directory/$artifact_name" ]] || {
    print -u2 "Artifact not found beside checksum: $artifact_name"
    exit 1
  }

  (
    cd "$checksum_directory"
    /usr/bin/shasum -a 256 -c "$checksum_name"
  )
}

for checksum_argument in "$@"; do
  verify_checksum "$checksum_argument"
done

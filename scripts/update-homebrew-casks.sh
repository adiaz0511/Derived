#!/bin/zsh

set -euo pipefail

readonly project_root="${0:A:h:h}"
version=""
sha256=""
tap_root=""

function usage {
  print -r -- "Usage: scripts/update-homebrew-casks.sh --version VERSION --sha256 SHA256 --tap-root PATH"
}

while (( $# > 0 )); do
  case "$1" in
    --version) version="${2:?Missing value for --version}"; shift 2 ;;
    --sha256) sha256="${2:?Missing value for --sha256}"; shift 2 ;;
    --tap-root) tap_root="${2:A}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$' ]] || { print -u2 "Invalid version: $version"; exit 2; }
[[ "$sha256" =~ '^[0-9a-f]{64}$' ]] || { print -u2 "Invalid SHA-256: $sha256"; exit 2; }
[[ -d "$tap_root" ]] || { print -u2 "Tap directory does not exist: $tap_root"; exit 2; }

mkdir -p "$tap_root/Casks"
for cask in derived derived-tools; do
  template="$project_root/Packaging/Homebrew/Casks/$cask.rb.template"
  output="$tap_root/Casks/$cask.rb"
  [[ -f "$template" ]] || { print -u2 "Missing template: $template"; exit 1; }
  sed \
    -e "s/__VERSION__/$version/g" \
    -e "s/__SHA256__/$sha256/g" \
    "$template" > "$output"
done

print "Updated Homebrew casks for Derived $version."

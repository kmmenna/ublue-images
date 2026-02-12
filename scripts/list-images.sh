#!/usr/bin/env bash
# Outputs one line per image: distro variant base
# Used by Justfile and CI to iterate over all images.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if command -v yq &>/dev/null; then
  for distro in $(yq eval 'keys | .[]' "$ROOT/images.yaml"); do
    for variant in $(yq eval '.["'"$distro"'"] | keys | .[]' "$ROOT/images.yaml"); do
      base=$(yq eval '.["'"$distro"'"]["'"$variant"'"].base' "$ROOT/images.yaml")
      echo "$distro $variant $base"
    done
  done
else
  awk '
    /^[a-z].*:/ { gsub(/:/, ""); distro=$1 }
    /^  [a-z].*:/ { gsub(/:/, ""); variant=$1 }
    /base:/ { sub(/.*base:[[:space:]]*/, ""); print distro, variant, $0 }
  ' "$ROOT/images.yaml"
fi

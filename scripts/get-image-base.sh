#!/usr/bin/env bash
# Usage: get-image-base.sh <distro> <variant>
# Outputs the base image for the given distro/variant from images.yaml.
set -euo pipefail
DISTRO="${1:?distro required}"
VARIANT="${2:?variant required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if command -v yq &>/dev/null; then
  yq eval '.["'"$DISTRO"'"]["'"$VARIANT"'"].base' "$ROOT/images.yaml"
else
  awk -v d="$DISTRO" -v v="$VARIANT" '
    $0 ~ "^" d ":" { in_d=1; next }
    in_d && $0 ~ "^  " v ":" { in_v=1; next }
    in_v && /base:/ { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }
    in_d && $0 ~ "^  [a-z]" && $0 !~ "^  " v ":" { in_v=0 }
    $0 ~ "^[a-z]" && $0 !~ "^" d ":" { in_d=0 }
  ' "$ROOT/images.yaml"
fi

#!/usr/bin/env bash
# Outputs a JSON array of images to build for CI.
# Each element: {"distro":"...","variant":"...","base":"..."}
# If CHANGED_FILES is set (newline-separated), only images whose sources changed are included.
# Otherwise (e.g. workflow_dispatch or schedule), all images are included.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

all_images_json() {
  # Output JSON array from images.yaml (using awk for portability; no yq required).
  awk '
    BEGIN { first=1; printf "[" }
    /^[a-z].*:/ { gsub(/:/, ""); distro=$1 }
    /^  [a-z].*:/ { gsub(/:/, ""); variant=$1 }
    /base:/ { sub(/.*base:[[:space:]]*/, ""); base=$0
      if (!first) printf ","
      printf "{\"distro\":\"%s\",\"variant\":\"%s\",\"base\":\"%s\"}", distro, variant, base
      first=0
    }
    END { printf "]" }
  ' images.yaml
}

affected_images() {
  local changed="$1"
  local distro variant base
  local json_list=""
  local first=1
  while read -r distro variant base; do
    # Include this image if any affecting path changed: global, this distro (any file under it), Containerfile, images.yaml
    if echo "$changed" | grep -qE "^(build_files/global\.sh|build_files/build-wrapper\.sh|build_files/build\.sh|Containerfile|images\.yaml)$"; then
      : "affected (global)"
    elif echo "$changed" | grep -qE "^build_files/${distro}/"; then
      : "affected (distro)"
    else
      continue
    fi
    base_escaped=$(echo "$base" | sed 's/"/\\"/g;s/\\/\\\\/g')
    if [[ $first -eq 1 ]]; then first=0; else json_list+=","; fi
    json_list+="{\"distro\":\"$distro\",\"variant\":\"$variant\",\"base\":\"$base_escaped\"}"
  done < <(./scripts/list-images.sh | awk '{print $1, $2, $3}')
  echo "[$json_list]"
}

if [[ -z "${CHANGED_FILES:-}" ]]; then
  # Build all images (schedule, workflow_dispatch, or first push)
  all_images_json
else
  affected_images "$CHANGED_FILES"
fi

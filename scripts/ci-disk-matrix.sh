#!/usr/bin/env bash
# Outputs a JSON array for build-disk matrix: each image × (qcow2, anaconda-iso).
# Each element: {"distro":"...","variant":"...","disk-type":"qcow2|anaconda-iso"}
# On pull_request, skip images not yet published to GHCR (PRs do not push packages).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ghcr_image_exists() {
  local image="$1"
  local registry="${IMAGE_REGISTRY:-}"
  local ns="${registry#ghcr.io/}"
  ns="${ns,,}"
  image="${image,,}"
  if [[ -z "$ns" ]]; then
    return 1
  fi
  local token code
  token=$(curl -sS "https://ghcr.io/token?service=ghcr.io&scope=repository:${ns}/${image}:pull" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))')
  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    -H "Authorization: Bearer ${token}" \
    "https://ghcr.io/v2/${ns}/${image}/manifests/latest" || echo 000)
  [[ "$code" == "200" ]]
}

first=1
echo -n "["
while read -r distro variant _base; do
  if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
    if ! ghcr_image_exists "${distro}-${variant}"; then
      continue
    fi
  fi
  for disk_type in qcow2 anaconda-iso; do
    if [[ $first -eq 1 ]]; then first=0; else echo -n ","; fi
    echo -n "{\"distro\":\"$distro\",\"variant\":\"$variant\",\"disk-type\":\"$disk_type\"}"
  done
done < <(./scripts/list-images.sh | awk '{print $1, $2, $3}')
echo "]"

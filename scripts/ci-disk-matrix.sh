#!/usr/bin/env bash
# Outputs a JSON array for build-disk matrix: each image × (qcow2, anaconda-iso).
# Each element: {"distro":"...","variant":"...","disk-type":"qcow2|anaconda-iso"}
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

first=1
echo -n "["
while read -r distro variant _base; do
  for disk_type in qcow2 anaconda-iso; do
    if [[ $first -eq 1 ]]; then first=0; else echo -n ","; fi
    echo -n "{\"distro\":\"$distro\",\"variant\":\"$variant\",\"disk-type\":\"$disk_type\"}"
  done
done < <(./scripts/list-images.sh | awk '{print $1, $2, $3}')
echo "]"

#!/bin/bash
# Orchestrates layered customizations: global -> distro common -> variant.
# Expects DISTRO and VARIANT in the environment (set via Containerfile ARG/ENV).

set -ouex pipefail

CTX="${CTX:-/ctx}"

run_script() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "Running: $path"
    bash -e "$path"
  fi
}

run_script "${CTX}/global.sh"
run_script "${CTX}/${DISTRO}/common.sh"
run_script "${CTX}/${DISTRO}/${VARIANT}.sh"

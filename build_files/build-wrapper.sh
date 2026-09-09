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

# Refresh desktop/MIME DBs after all layers (covers noscripts installs and future packages).
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
update-mime-database /usr/share/mime >/dev/null 2>&1 || true

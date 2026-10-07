#!/bin/bash
# Ensure RPM Fusion Nonfree repository definitions are available while keeping
# them disabled by default. Callers must explicitly enable only the repositories
# needed for an individual DNF transaction.
set -ouex pipefail

FEDORA_VERSION="$(rpm -E %fedora)"

# Generic RPM Fusion Nonfree repositories (base, updates, testing).
if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
  dnf5 install -y     "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
fi

# Fedora ships the opt-in repository definitions for third-party software,
# including rpmfusion-nonfree-steam.
dnf5 install -y fedora-workstation-repositories

# Prevent RPM Fusion Nonfree from participating in unrelated package resolution.
sed -i 's/^enabled=1$/enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree*.repo

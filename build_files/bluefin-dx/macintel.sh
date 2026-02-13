#!/bin/bash
# Bluefin DX macintel variant
set -ouex pipefail

# Mac Intel-specific packages or configuration.

# --- Broadcom WiFi (ex: BCM4360) proprietary driver setup using RPM Fusion non-free ---

# 1. Enable RPM Fusion non-free repository (not enabled by default in recent ublue images)
FEDORA_VERSION=$(rpm -E %fedora)
dnf5 install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

# 2. Install akmods to create the 'akmods' user (not intended to run as root)
dnf5 install -y akmods

# 3. Install broadcom-wl driver without running scriptlets:
# The %post script of akmod-wl tries to run akmods (which fails as root).
# Workaround: use a temporary DNF config with 'tsflags=noscripts' because '--setopt' may not properly apply 'tsflags' on all DNF5 versions.
DNF_NOSCRIPTS_CONF=$(mktemp)
printf '[main]\ntsflags=noscripts\n' > "${DNF_NOSCRIPTS_CONF}"
dnf5 -c "${DNF_NOSCRIPTS_CONF}" install -y broadcom-wl
rm -f "${DNF_NOSCRIPTS_CONF}"

# 4. Install kernel-devel for module compilation (uname -r in CI refers to the host kernel, not the image kernel)
dnf5 install -y kernel-devel

# 5. Determine the installed image kernel version (use the version of installed kernel-devel, not the host)
KERNEL_RELEASE=$(rpm -q kernel-devel --qf '%{version}-%{release}.%{arch}\n' | head -1)

# 6. Build the Broadcom wl kernel module RPM as the 'akmods' user, then install it as root:
# - akmods as user can build but can't install the RPM; use akmodsbuild to generate the RPM for root to install.
# - akmodsbuild ignores TMPDIR and uses mktemp in /tmp; in containers /tmp must be writable by 'akmods'.
AKMODS_OUT=$(mktemp -d)
chown akmods:akmods "${AKMODS_OUT}"
WL_SRC_RPM=$(find /usr/src/akmods -name 'wl-kmod*.src.rpm' | head -1)
chmod 1777 /tmp
runuser -u akmods -- akmodsbuild -o "${AKMODS_OUT}" -k "${KERNEL_RELEASE}" "${WL_SRC_RPM}"

dnf5 install -y "${AKMODS_OUT}"/*.rpm

# 7. Clean up
rm -rf "${AKMODS_OUT}"

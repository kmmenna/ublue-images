#!/bin/bash

set -ouex pipefail

FEDORA_VERSION=$(cat /etc/fedora-release | cut -d' ' -f 3)

### Install packages (global - applied to all images)

### Install Proton AG official packages

# Proton VPN - Add official repository and install
# Install with tsflags=noscripts: the daemon's %posttrans tries to run systemctl (no systemd in container build).
wget -q "https://repo.protonvpn.com/fedora-${FEDORA_VERSION}-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.3-1.noarch.rpm" -O /tmp/protonvpn-stable-release.rpm
dnf5 install -y /tmp/protonvpn-stable-release.rpm
rm -f /tmp/protonvpn-stable-release.rpm
dnf5 check-update --refresh || true
DNF_NOSCRIPTS_CONF=$(mktemp)
printf '[main]\ntsflags=noscripts\n' > "${DNF_NOSCRIPTS_CONF}"
dnf5 -c "${DNF_NOSCRIPTS_CONF}" install -y proton-vpn-gnome-desktop
rm -f "${DNF_NOSCRIPTS_CONF}"
systemctl enable me.proton.vpn.daemon

# Proton Mail Desktop App - Download and install RPM
wget -q "https://proton.me/download/mail/linux/ProtonMail-desktop-beta.rpm" -O /tmp/ProtonMail-desktop-beta.rpm
dnf5 install -y /tmp/ProtonMail-desktop-beta.rpm
rm -f /tmp/ProtonMail-desktop-beta.rpm

# Proton Pass - Download and install RPM
wget -q "https://proton.me/download/PassDesktop/linux/x64/ProtonPass.rpm" -O /tmp/ProtonPass.rpm
dnf5 install -y /tmp/ProtonPass.rpm
rm -f /tmp/ProtonPass.rpm

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket


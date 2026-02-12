#!/bin/bash

set -ouex pipefail

### Install packages (global - applied to all images)

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

### Install Proton AG official packages

# Proton VPN - Add official repository and install
# Note: Using rpm --noposttrans to skip scriptlets that require systemd
# (systemd is not available during container image build, but services will work at runtime)
FEDORA_VERSION=$(cat /etc/fedora-release | cut -d' ' -f 3)
wget -q "https://repo.protonvpn.com/fedora-${FEDORA_VERSION}-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.3-1.noarch.rpm" -O /tmp/protonvpn-stable-release.rpm
dnf5 install -y /tmp/protonvpn-stable-release.rpm
dnf5 check-update --refresh || true
# Download Proton VPN packages with all dependencies, then install with rpm skipping posttrans scriptlets
WORKDIR=$(mktemp -d)
cd "${WORKDIR}"
# Download package and all its dependencies
dnf5 download -y --resolve proton-vpn-gnome-desktop
# Install all downloaded RPMs skipping posttrans scriptlets (which require systemd)
rpm -ivh --noposttrans "${WORKDIR}"/*.rpm
# Verify installation succeeded
rpm -q proton-vpn-gnome-desktop
cd -
rm -rf "${WORKDIR}"

# Proton Mail Desktop App - Download and install RPM
wget -q "https://proton.me/download/mail/linux/ProtonMail-desktop-beta.rpm" -O /tmp/ProtonMail-desktop-beta.rpm
dnf5 install -y /tmp/ProtonMail-desktop-beta.rpm

# Proton Pass - Download and install RPM
wget -q "https://proton.me/download/PassDesktop/linux/x64/ProtonPass.rpm" -O /tmp/ProtonPass.rpm
dnf5 install -y /tmp/ProtonPass.rpm

# Clean up downloaded RPM files
rm -f /tmp/protonvpn-stable-release.rpm /tmp/ProtonMail-desktop-beta.rpm /tmp/ProtonPass.rpm

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket


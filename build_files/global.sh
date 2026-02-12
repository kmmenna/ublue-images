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
# Note: Installing dependencies first with dnf5, then Proton VPN packages with rpm --noposttrans
# to skip scriptlets that require systemd (systemd is not available during container image build)
FEDORA_VERSION=$(cat /etc/fedora-release | cut -d' ' -f 3)
wget -q "https://repo.protonvpn.com/fedora-${FEDORA_VERSION}-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.3-1.noarch.rpm" -O /tmp/protonvpn-stable-release.rpm
dnf5 install -y /tmp/protonvpn-stable-release.rpm
dnf5 check-update --refresh || true
# Install/upgrade all dependencies first using dnf5 (handles conflicts and updates properly)
dnf5 install -y $(dnf5 repoquery --requires --resolve proton-vpn-gnome-desktop 2>/dev/null | grep -v "^proton-vpn" | xargs) || true
# Download only Proton VPN packages (proton-vpn-*)
WORKDIR=$(mktemp -d)
cd "${WORKDIR}"
dnf5 download -y proton-vpn-gnome-desktop
# Filter to only Proton VPN packages to avoid conflicts with already installed dependencies
PROTON_RPMS=$(ls "${WORKDIR}"/proton-vpn-*.rpm 2>/dev/null)
if [ -n "${PROTON_RPMS}" ]; then
    # Install Proton VPN packages skipping posttrans scriptlets (which require systemd)
    # Use -Uvh to allow upgrades if packages are already installed
    rpm -Uvh --noposttrans ${PROTON_RPMS}
fi
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


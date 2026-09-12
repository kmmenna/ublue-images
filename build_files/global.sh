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
# Enable daemon unit(s) from proton-vpn-daemon (exact unit name varies by package version)
for unit in $(rpm -ql proton-vpn-daemon 2>/dev/null | grep '\.service$'); do
  systemctl enable "$(basename "$unit")"
done

# Proton Mail Desktop App - Download and install RPM
wget -q "https://proton.me/download/mail/linux/ProtonMail-desktop-beta.rpm" -O /tmp/ProtonMail-desktop-beta.rpm
dnf5 install -y /tmp/ProtonMail-desktop-beta.rpm
rm -f /tmp/ProtonMail-desktop-beta.rpm

# Proton Pass - Download and install RPM
wget -q "https://proton.me/download/PassDesktop/linux/x64/ProtonPass.rpm" -O /tmp/ProtonPass.rpm
dnf5 install -y /tmp/ProtonPass.rpm
rm -f /tmp/ProtonPass.rpm

# Cursor IDE - install RPM (avoid Flatpak issues)
CURSOR_ARCH="$(uname -m)"
case "${CURSOR_ARCH}" in
  x86_64) CURSOR_ARCH="x64" ;;
  aarch64) CURSOR_ARCH="arm64" ;;
  *)
    echo "Unsupported architecture for Cursor RPM: $(uname -m)" >&2
    exit 1
    ;;
esac
wget -q "https://api2.cursor.sh/updates/download/golden/linux-${CURSOR_ARCH}-rpm/cursor/latest" -O /tmp/cursor.rpm
DNF_NOSCRIPTS_CONF_CURSOR="$(mktemp)"
printf '[main]\ntsflags=noscripts\n' > "${DNF_NOSCRIPTS_CONF_CURSOR}"
dnf5 -c "${DNF_NOSCRIPTS_CONF_CURSOR}" install -y /tmp/cursor.rpm
rm -f "${DNF_NOSCRIPTS_CONF_CURSOR}"
rm -f /tmp/cursor.rpm

# ChatGPT Desktop / Codex App - install official RPM
# Install with tsflags=noscripts: %post runs refresh_dnf5_keys (python/libdnf5)
# and apparmor_parser without || true — can fail in container builds.
# Unlike Cursor, OpenAI ships chatgpt.repo + GPG keys in the payload; disable
# the repo so updates come from image rebuilds, not rpm-ostree/dnf layering.
CHATGPT_ARCH="$(uname -m)"
case "${CHATGPT_ARCH}" in
  x86_64) CHATGPT_RPM_ARCH="x86_64" ;;
  aarch64) CHATGPT_RPM_ARCH="aarch64" ;;
  *)
    echo "Unsupported architecture for ChatGPT RPM: ${CHATGPT_ARCH}" >&2
    exit 1
    ;;
esac
wget -q \
  "https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.${CHATGPT_RPM_ARCH}.rpm" \
  -O /tmp/chatgpt.rpm
DNF_NOSCRIPTS_CONF_CHATGPT="$(mktemp)"
printf '[main]\ntsflags=noscripts\n' > "${DNF_NOSCRIPTS_CONF_CHATGPT}"
dnf5 -c "${DNF_NOSCRIPTS_CONF_CHATGPT}" install -y /tmp/chatgpt.rpm
rm -f "${DNF_NOSCRIPTS_CONF_CHATGPT}"
rm -f /tmp/chatgpt.rpm
if [ -f /etc/yum.repos.d/chatgpt.repo ]; then
  sed -i 's/^enabled=1$/enabled=0/' /etc/yum.repos.d/chatgpt.repo
fi

# OpenLogi - official RPM (https://openlogi.org/#install)
# Install with tsflags=noscripts: %post runs udevadm with set -eu (no udev in
# container builds). udev rules ship in the payload and apply on first boot.
# Enable the packaged user unit globally so the HID++ agent starts at login.
OPENLOGI_ARCH="$(uname -m)"
case "${OPENLOGI_ARCH}" in
  x86_64) OPENLOGI_GH_ARCH="amd64" ;;
  aarch64) OPENLOGI_GH_ARCH="arm64" ;;
  *)
    echo "Unsupported architecture for OpenLogi RPM: ${OPENLOGI_ARCH}" >&2
    exit 1
    ;;
esac
OPENLOGI_TAG="$(curl -fsSL -D - -o /dev/null https://github.com/AprilNEA/OpenLogi/releases/latest | awk 'tolower($1)=="location:"{gsub("\r","",$2); n=split($2,a,"/"); print a[n]; exit}')"
if [ -z "${OPENLOGI_TAG}" ]; then
  echo "Failed to resolve latest OpenLogi release tag" >&2
  exit 1
fi
wget -q \
  "https://github.com/AprilNEA/OpenLogi/releases/download/${OPENLOGI_TAG}/openlogi-${OPENLOGI_TAG}-linux-${OPENLOGI_GH_ARCH}.rpm" \
  -O /tmp/openlogi.rpm
DNF_NOSCRIPTS_CONF_OPENLOGI="$(mktemp)"
printf '[main]\ntsflags=noscripts\n' > "${DNF_NOSCRIPTS_CONF_OPENLOGI}"
dnf5 -c "${DNF_NOSCRIPTS_CONF_OPENLOGI}" install -y /tmp/openlogi.rpm
rm -f "${DNF_NOSCRIPTS_CONF_OPENLOGI}"
rm -f /tmp/openlogi.rpm
systemctl --global enable openlogi-agent.service

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket


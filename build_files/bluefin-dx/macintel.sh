#!/bin/bash
# Bluefin DX macintel variant
set -ouex pipefail

# Mac Intel-specific packages or configuration.

# Broadcom WiFi (ex.: BCM4360) - driver proprietário do RPM Fusion non-free
# Habilitar repositório non-free (não vem habilitado por padrão em imagens ublue recentes)
FEDORA_VERSION=$(rpm -E %fedora)
dnf5 install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
dnf5 install -y broadcom-wl
# Rebuild dos módulos do kernel para a imagem (akmods)
akmods --kernels "$(uname -r)"

#!/bin/bash
# Bluefin DX macintel variant
set -ouex pipefail

# Mac Intel-specific packages or configuration.

# Broadcom WiFi (ex.: BCM4360) - driver proprietário do RPM Fusion non-free
# Habilitar repositório non-free (não vem habilitado por padrão em imagens ublue recentes)
FEDORA_VERSION=$(rpm -E %fedora)
dnf5 install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
# Instalar akmods primeiro para criar o usuário akmodsbuild (akmods não roda como root)
dnf5 install -y akmods
# Instalar broadcom-wl sem rodar scriptlets: o %post do akmod-wl chama akmods e falha como root
dnf5 install -y --setopt=tsflags=noscripts broadcom-wl
# Compilar o módulo do kernel como usuário akmodsbuild
runuser -u akmodsbuild -- akmods --kernels "$(uname -r)"

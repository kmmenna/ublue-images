#!/bin/bash
# Bluefin DX macintel variant
set -ouex pipefail

# Mac Intel-specific packages or configuration.

# Broadcom WiFi (ex.: BCM4360) - driver proprietário do RPM Fusion non-free
# Habilitar repositório non-free (não vem habilitado por padrão em imagens ublue recentes)
FEDORA_VERSION=$(rpm -E %fedora)
dnf5 install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
# Instalar akmods primeiro para criar o usuário akmods (akmods não roda como root)
dnf5 install -y akmods
# Instalar broadcom-wl sem rodar scriptlets: o %post do akmod-wl chama akmods e falha como root.
# Usar config temporário porque --setopt pode não aplicar tsflags em todas as versões do dnf5.
DNF_NOSCRIPTS_CONF=$(mktemp)
printf '[main]\ntsflags=noscripts\n' > "${DNF_NOSCRIPTS_CONF}"
dnf5 -c "${DNF_NOSCRIPTS_CONF}" install -y broadcom-wl
rm -f "${DNF_NOSCRIPTS_CONF}"
# kernel-devel necessário para compilar o módulo; no CI uname -r é o kernel do host (ex.: azure), não da imagem
dnf5 install -y kernel-devel
# Compilar para o kernel da imagem (versão do kernel-devel instalado), não do host
KERNEL_RELEASE=$(rpm -q kernel-devel --qf '%{version}-%{release}.%{arch}\n' | head -1)
runuser -u akmods -- akmods --kernels "${KERNEL_RELEASE}"

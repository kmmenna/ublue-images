#!/bin/bash
# Gaming stack shared by every image except Bazzite (which already ships it).
set -ouex pipefail

# These packages are provided by Fedora.
dnf5 install -y gamescope gamemode mangohud

# Steam is provided by RPM Fusion Nonfree. Keep those repositories disabled by
# default and enable them only for this transaction.
source /ctx/shared/rpmfusion-nonfree.sh

steam_repos=(
  --enablerepo=rpmfusion-nonfree
  --enablerepo=rpmfusion-nonfree-updates
  --enablerepo=rpmfusion-nonfree-steam
)

# Aurora ships parts of its multimedia stack from Negativo17. Enable the same
# repository for this transaction so 32-bit Steam dependencies are resolved
# from the matching multimedia stack instead of conflicting RPM Fusion builds.
if [[ "${DISTRO}" == "aurora-dx" ]]; then
  steam_repos+=(--enablerepo=fedora-multimedia)
fi

dnf5 install -y "${steam_repos[@]}" steam

dnf5 clean all

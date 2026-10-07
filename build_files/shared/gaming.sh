#!/bin/bash
# Gaming stack shared by every image except Bazzite (which already ships it).
set -ouex pipefail

# These packages are provided by Fedora.
dnf5 install -y gamescope gamemode mangohud

# Steam is provided by RPM Fusion Nonfree. Keep those repositories disabled by
# default and enable them only for this transaction.
source /ctx/shared/rpmfusion-nonfree.sh
dnf5 install -y \
  --enablerepo=rpmfusion-nonfree \
  --enablerepo=rpmfusion-nonfree-updates \
  --enablerepo=rpmfusion-nonfree-steam \
  steam

dnf5 clean all

#!/bin/bash
# Gaming stack shared by every image except Bazzite (which already ships it).
set -ouex pipefail

dnf5 install -y steam gamescope gamemode mangohud
dnf5 clean all

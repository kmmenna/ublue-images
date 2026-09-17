#!/bin/bash
# Gaming stack shared by every image except Bazzite (which already ships it).
set -ouex pipefail

# Steam is i686 and requires pipewire-alsa(x86-32) when PipeWire is present.
# pipewire-libs.i686 needs libfdk-aac.so.2; Fedora 44 ships libfdk-aac.x86_64,
# which obsoletes fdk-aac{,-free}.i686, so the matching i686 codec must be
# in the same transaction.
dnf5 install -y \
  libfdk-aac.i686 \
  steam \
  gamescope \
  gamemode \
  mangohud
dnf5 clean all

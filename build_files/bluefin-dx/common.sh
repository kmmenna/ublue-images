#!/bin/bash
# Bluefin DX-specific customizations (applied to all bluefin-dx variants: macintel, nvidia)
set -ouex pipefail

# --- Remove not used programs ---

# Flatpak: GNOME Text Editor
flatpak uninstall --system --noninteractive org.gnome.TextEditor 2>/dev/null || true


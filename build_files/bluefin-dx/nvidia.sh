#!/bin/bash
# Bluefin nvidia variant
set -ouex pipefail

# Bluefin's upstream NVIDIA base currently omits the 32-bit NVIDIA userspace.
source /ctx/shared/nvidia-multilib.sh

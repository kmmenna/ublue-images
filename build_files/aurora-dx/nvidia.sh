#!/bin/bash
# Aurora nvidia variant
set -ouex pipefail

# Aurora's upstream NVIDIA base currently omits the 32-bit NVIDIA userspace.
source /ctx/shared/nvidia-multilib.sh

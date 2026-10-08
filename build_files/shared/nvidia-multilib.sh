#!/bin/bash
# Install only 32-bit NVIDIA userspace matching the driver in the upstream base.
# Never upgrade or downgrade the x86_64 NVIDIA stack in this layer.
set -ouex pipefail

multilib_packages=()
for package in nvidia-driver-libs nvidia-driver-cuda-libs; do
  # Include epoch: NVIDIA packages can have an epoch different from zero.
  base_evr="$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "${package}.x86_64")"
  multilib_packages+=("${package}-${base_evr}.i686")
done

# Explicit NEVRAs prevent DNF from selecting a newer i686 driver. Excluding
# x86_64 candidates from the available repos prevents dependency resolution
# from upgrading the existing NVIDIA driver (or any other 64-bit base package).
# If the exact 32-bit build cannot be resolved, fail instead of drifting.
dnf5 install -y \
  --enablerepo=fedora-nvidia \
  --no-allow-downgrade \
  --exclude='*.x86_64' \
  "${multilib_packages[@]}"

# Verify both architectures have identical epoch, version and release.
for package in nvidia-driver-libs nvidia-driver-cuda-libs; do
  x86_64_evr="$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "${package}.x86_64")"
  i686_evr="$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "${package}.i686")"

  if [[ "${x86_64_evr}" != "${i686_evr}" ]]; then
    echo "NVIDIA multilib version mismatch for ${package}: x86_64=${x86_64_evr} i686=${i686_evr}" >&2
    exit 1
  fi
done

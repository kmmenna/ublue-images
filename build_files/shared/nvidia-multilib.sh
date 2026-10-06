#!/bin/bash
# Shared NVIDIA multilib support for images whose upstream base omits 32-bit userspace.
set -ouex pipefail

dnf5 install -y \
  --enablerepo=fedora-nvidia \
  nvidia-driver-libs.i686 \
  nvidia-driver-cuda-libs.i686

# Keep the multilib NVIDIA stack aligned with the x86_64 driver already
# provided by the upstream image. Fail the image build on version drift.
for package in nvidia-driver-libs nvidia-driver-cuda-libs; do
  x86_64_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "${package}.x86_64")"
  i686_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "${package}.i686")"

  if [[ "${x86_64_version}" != "${i686_version}" ]]; then
    echo "NVIDIA multilib version mismatch for ${package}: x86_64=${x86_64_version} i686=${i686_version}" >&2
    exit 1
  fi
done

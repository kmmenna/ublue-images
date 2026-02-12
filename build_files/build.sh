#!/bin/bash
# Compatibility shim: runs build-wrapper with default distro/variant (bluefin/nvidia).
# For multi-image builds, the Containerfile passes DISTRO and VARIANT and invokes build-wrapper.sh directly.
export DISTRO="${DISTRO:-bluefin}"
export VARIANT="${VARIANT:-nvidia}"
exec /ctx/build-wrapper.sh

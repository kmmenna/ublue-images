# Base Image (set via --build-arg; default for local single-image builds)
# Must be declared before any FROM so it can be used in FROM ${BASE_IMAGE}
ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx:stable

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE}

## Other possible base images (see images.yaml for distro/variant -> base mapping):
# ghcr.io/ublue-os/bazzite:latest
# ghcr.io/ublue-os/bluefin-nvidia:stable
# ghcr.io/ublue-os/aurora-dx:stable
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## Layered customizations: global -> distro common -> variant (see build_files/build-wrapper.sh).
## Pass DISTRO and VARIANT via build-arg so the wrapper runs the correct scripts.

ARG DISTRO=bluefin
ARG VARIANT=desktop
ENV DISTRO=${DISTRO} VARIANT=${VARIANT}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build-wrapper.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint

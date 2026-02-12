export image_name := env("IMAGE_NAME", "image-template") # output image name, usually same as repo name, change as needed
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# List all distro/variant combinations from images.yaml
[group('Build')]
list-images:
    @./scripts/list-images.sh

# Build all images (every distro/variant in images.yaml)
[group('Build')]
build-all:
    #!/usr/bin/env bash
    set -euo pipefail
    while read -r distro variant _base; do
        just build "$distro" "$variant"
    done < <(./scripts/list-images.sh)

# This Justfile recipe builds a container image using Podman.
# Uses images.yaml for base image; layers: global -> distro common -> variant.
#
# Example: just build bluefin-dx macintel
#          just build aurora-dx nvidia
#
build distro variant:
    #!/usr/bin/env bash
    set -euo pipefail
    BASE_IMAGE=$(./scripts/get-image-base.sh "{{ distro }}" "{{ variant }}")
    IMAGE_TAG="{{ distro }}-{{ variant }}"
    TARGET_IMAGE="localhost/{{ image_name }}"

    BUILD_ARGS=()
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${BASE_IMAGE}")
    BUILD_ARGS+=("--build-arg" "DISTRO={{ distro }}")
    BUILD_ARGS+=("--build-arg" "VARIANT={{ variant }}")
    if [[ -z "$(git status -s 2>/dev/null)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD 2>/dev/null || true)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --tag "${TARGET_IMAGE}:${IMAGE_TAG}" \
        .

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image.
# Parameters: target_image, tag (e.g. localhost/image_name, bluefin-dx-macintel), type, config.
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Build a QCOW2 virtual machine image (distro/variant from images.yaml)
# Example: just build-qcow2 bluefin-dx macintel
[group('Build Virtal Machine Image')]
build-qcow2 distro variant:
    just build (distro) (variant)
    just _build-bib ("localhost/" + image_name) (distro + "-" + variant) qcow2 "disk_config/disk.toml"

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw distro variant:
    just build (distro) (variant)
    just _build-bib ("localhost/" + image_name) (distro + "-" + variant) raw "disk_config/disk.toml"

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso distro variant:
    just build (distro) (variant)
    just _build-bib ("localhost/" + image_name) (distro + "-" + variant) iso "disk_config/iso.toml"

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 distro variant:
    just build (distro) (variant)
    just _build-bib ("localhost/" + image_name) (distro + "-" + variant) qcow2 "disk_config/disk.toml"

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw distro variant:
    just build (distro) (variant)
    just _build-bib ("localhost/" + image_name) (distro + "-" + variant) raw "disk_config/disk.toml"

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso distro variant:
    just build (distro) (variant)
    just _build-bib ("localhost/" + image_name) (distro + "-" + variant) iso "disk_config/iso.toml"

# Internal: run VM (called by run-vm-* with type and config from script).
_run-vm-inner $distro $variant $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the disk image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "{{ distro }}" "{{ variant }}"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp 2>/dev/null); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image. Example: just run-vm-qcow2 bluefin-dx macintel
[group('Run Virtal Machine')]
run-vm-qcow2 distro variant:
    just _run-vm-inner (distro) (variant) qcow2 "disk_config/disk.toml"

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw distro variant:
    just _run-vm-inner (distro) (variant) raw "disk_config/disk.toml"

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso distro variant:
    just _run-vm-inner (distro) (variant) iso "disk_config/iso.toml"

# Run a virtual machine using systemd-vmspawn
# Example: just spawn-vm bluefin-dx macintel
[group('Run Virtal Machine')]
spawn-vm distro variant rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the disk image" && just build-qcow2 "{{ distro }}" "{{ variant }}"

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}


# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'

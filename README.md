# ublue-images

Repository for my custom [Universal Blue](https://universal-blue.org/) (ublue) container images. Images are based on Bluefin DX and Aurora DX, with layered customizations. The project builds container images for GitHub Container Registry (GHCR) and can produce bootable disk images (QCOW2, raw, ISO) via [Bootc Image Builder](https://github.com/osbuild/bootc-image-builder).

## Features

- **Multi-image matrix**: Builds several distro/variant combinations from a single repo (see `images.yaml`).
- **Layered customizations**: Global → distro common → variant scripts in `build_files/`.
- **CI/CD**: GitHub Actions build and push images on push/PR to main; optional Cosign signing.
- **Disk images**: Optional local builds of QCOW2, raw, or anaconda ISO using Bootc Image Builder and `just`.

## Project structure

```
├── build_files/           # Image customizations (run at build time)
│   ├── global.sh          # Applied to all images
│   ├── build-wrapper.sh   # Orchestrator: global → distro common → variant
│   ├── build.sh           # Shim for default distro/variant
│   ├── bluefin-dx/
│   │   ├── common.sh      # Bluefin DX–specific
│   │   ├── macintel.sh
│   │   └── nvidia.sh
│   └── aurora-dx/
│       ├── common.sh
│       └── nvidia.sh
├── disk_config/           # Bootc Image Builder configs
│   ├── disk.toml          # QCOW2/raw disk layout
│   └── iso.toml           # Anaconda ISO (IMAGE_REF replaced in CI)
├── scripts/                # CI and local tooling
│   ├── ci-matrix.sh       # Build matrix from images.yaml + changed files
│   ├── ci-disk-matrix.sh  # Matrix for disk image workflow
│   ├── list-images.sh     # List distro/variant from images.yaml
│   ├── get-image-base.sh  # Base image for a distro/variant
│   └── get-next-tag-number.sh  # Next date tag for GHCR (user packages)
├── images.yaml            # Distro/variant → base image mapping
├── Containerfile          # Multi-stage build; uses build_files via build-wrapper
├── Justfile               # Local build and disk image recipes
└── .github/workflows/
    ├── build.yml          # Build and push container images
    └── build-disk.yml     # Build disk images (QCOW2, raw, anaconda-iso)
```

## Images (distros and variants)

Defined in `images.yaml`. Every image receives **global** customizations first, then **distro common**, then **variant-specific** (see `build_files/`).

### Global customizations (all images)

- **Proton apps**: Proton Mail Desktop (beta), Proton Pass (official RPMs).
- **Services**: `podman.socket` enabled.

### Per-image summary

| Distro      | Variant  | Base image | Customizations |
|-------------|----------|------------|----------------|
| **bluefin-dx** | macintel | `ghcr.io/ublue-os/bluefin-dx:stable` | Global + **Broadcom WiFi**: RPM Fusion non-free, `akmods`, `broadcom-wl` (e.g. BCM4360); kernel-devel and wl kernel module built at image build time. |
| **bluefin-dx** | nvidia   | `ghcr.io/ublue-os/bluefin-dx-nvidia:stable` | Global only (Nvidia stack comes from base). |
| **aurora-dx**  | nvidia   | `ghcr.io/ublue-os/aurora-dx-nvidia:stable` | Global only (Nvidia stack comes from base). |

To add or change images, edit `images.yaml` and add or adjust scripts under `build_files/<distro>/` (`common.sh` and `<variant>.sh`).

## Prerequisites

- **Local container builds**: [Podman](https://podman.io/).
- **Justfile commands**: [just](https://github.com/casey/just).
- **Scripts**: `yq` (for `images.yaml`), `jq`, `bash`.
- **Disk images (optional)**: Root/sudo for Bootc Image Builder; `bootc-image-builder` container image (see `Justfile` / `BIB_IMAGE`).

## Local builds

List available images:

```bash
just list-images
```

Build a single container image (e.g. Bluefin DX macintel):

```bash
just build bluefin-dx macintel
```

Build all images:

```bash
just build-all
```

Default image name and tag can be set via environment variables `IMAGE_NAME` and `DEFAULT_TAG` (see top of `Justfile`).

## Disk images (QCOW2, raw, ISO)

Disk image builds require **root** (Bootc Image Builder runs privileged). Use `sudo`:

```bash
sudo just build-qcow2 bluefin-dx macintel
```

Similar commands: `build-raw`, `build-iso`. Output goes under `output/`. To run a VM from a QCOW2 image:

```bash
just run-vm-qcow2 bluefin-dx macintel
```

Or use `systemd-vmspawn`:

```bash
just spawn-vm bluefin-dx macintel
```

Configs: `disk_config/disk.toml` (QCOW2/raw), `disk_config/iso.toml` (anaconda ISO).

## Customization layers

At build time the Containerfile runs `build-wrapper.sh`, which executes in order:

1. **`global.sh`** — applied to every image.
2. **`build_files/<distro>/common.sh`** — applied to all variants of that distro.
3. **`build_files/<distro>/<variant>.sh`** — applied only to that (distro, variant).

Edit these scripts to add packages, repos, or other changes. The CI matrix only rebuilds images whose layers (or `Containerfile` / `images.yaml`) changed.

## CI/CD

- **`build.yml`**: On push/PR to default branch, computes which (distro, variant) pairs to build from changed files and `images.yaml`, then builds and pushes to GHCR. On the default branch (non-PR), images are tagged with a date-based tag (`YYYYMMDD.N`) and signed with Cosign if `SIGNING_SECRET` is set.
- **`build-disk.yml`**: Builds disk images (QCOW2, raw, anaconda-iso) per matrix from `scripts/ci-disk-matrix.sh`, using `disk_config/disk.toml` and `disk_config/iso.toml`.

Containers are published under `ghcr.io/${{ github.repository_owner }}/<package>`; the next date tag is determined from the **user’s** GHCR packages (see `scripts/get-next-tag-number.sh`).

## Verifying image signatures

If images are signed with Cosign, you can verify them using the public key in the repo:

```bash
cosign verify --key cosign.pub ghcr.io/<owner>/<image>:<tag>
```

## Justfile reference

| Command | Description |
|--------|-------------|
| `just list-images` | List distro/variant from `images.yaml` |
| `just build <distro> <variant>` | Build one container image |
| `just build-all` | Build all images |
| `just build-qcow2/raw/iso <distro> <variant>` | Build container + disk image |
| `just run-vm-qcow2/raw/iso <distro> <variant>` | Run VM from disk image |
| `just spawn-vm <distro> <variant>` | Run with systemd-vmspawn |
| `just lint` | Run shellcheck on shell scripts |
| `just format` | Run shfmt on shell scripts |
| `just check` / `just fix` | Check/fix Justfile syntax |
| `just clean` | Remove build artifacts |

## License

See [LICENSE](LICENSE).

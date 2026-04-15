# Slurm Package Builder

Build Slurm and Pyxis packages for Rocky Linux and Ubuntu with GPU plugin support (NVIDIA NVML and AMD ROCm SMI).

## Docker builds (recommended)

Packages are output as tarballs to `./output/`.

### Slurm

```bash
make docker-build-ubuntu-amd64    # Ubuntu amd64 (NVML + ROCm SMI)
make docker-build-ubuntu-arm64    # Ubuntu arm64 (NVML only)
make docker-build-rocky-amd64     # Rocky amd64 (NVML + ROCm SMI)
make docker-build-rocky-arm64     # Rocky arm64 (NVML only)
make docker-build-all             # All Slurm targets
```

### Pyxis

Pyxis builds require the corresponding Slurm build to have completed first.

```bash
make docker-build-pyxis-ubuntu-amd64
make docker-build-pyxis-ubuntu-arm64
make docker-build-pyxis-rocky-amd64
make docker-build-pyxis-rocky-arm64
make docker-build-pyxis-all
```

### Custom versions

```bash
# Slurm and GPU versions
make docker-build-ubuntu-amd64 SLURM_VERSION=25.11.4 SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
make docker-build-ubuntu-amd64 CUDA_VERSION=13-2 ROCM_VERSION=6.4.2

# OS versions
make docker-build-ubuntu-amd64 UBUNTU_VERSION=24.04
make docker-build-rocky-amd64 ROCKY_VERSION=9.3

# Pyxis version
make docker-build-pyxis-ubuntu-amd64 PYXIS_VERSION=0.23.0
```

### Prerequisites

- Docker with buildx plugin
- For local arm64 builds: QEMU user-static (registered automatically via `docker-setup`)

## Direct builds (inside a container or build host)

These targets run directly on the host and are used internally by the Docker builds.

```bash
make build-ubuntu   # Build .deb packages (requires Ubuntu/Debian)
make build-rocky    # Build .rpm packages (requires Rocky/RHEL 9)
```

## GitHub Actions

The `release.yml` workflow builds all Slurm and Pyxis targets in parallel via manual dispatch, then creates a draft release with all artifacts. Inputs allow overriding all versions.

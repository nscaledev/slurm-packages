# Slurm Package Builder

Build Slurm packages for Rocky Linux and Ubuntu with GPU plugin support (NVIDIA NVML and AMD ROCm SMI).

## Docker builds (recommended)

Packages are output as tarballs to `./output/`, named with the Slurm version, distro, architecture, and GPU library versions.

```bash
# Build Ubuntu amd64 (includes NVML + ROCm SMI)
make docker-build-ubuntu-amd64

# Build Ubuntu arm64 (includes NVML only, ROCm is x86_64 only)
make docker-build-ubuntu-arm64

# Build Rocky amd64 (includes NVML + ROCm SMI)
make docker-build-rocky-amd64

# Build Rocky arm64 (includes NVML only)
make docker-build-rocky-arm64

# Build all targets
make docker-build-all

# Clean output and remove buildx builder
make docker-clean
```

### Custom versions

```bash
# Override Slurm version
make docker-build-ubuntu-amd64 SLURM_VERSION=25.11.4 SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c

# Override GPU library versions
make docker-build-ubuntu-amd64 CUDA_VERSION=13-2 ROCM_VERSION=6.4.2

# Override OS versions
make docker-build-ubuntu-amd64 UBUNTU_VERSION=24.04
make docker-build-rocky-amd64 ROCKY_VERSION=9.3
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

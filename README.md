# Slurm Package Builder

Build Slurm packages for Rocky Linux and Ubuntu with GPU plugin support (NVIDIA NVML or AMD ROCm SMI).

Separate builds are produced per GPU type so you can deploy the right variant per node.

## Docker builds (recommended)

Packages are output as tarballs to `./output/`, named with the Slurm version, distro, architecture, and GPU library version.

```bash
# Build Ubuntu 24.04 amd64 with NVIDIA NVML
make docker-build-ubuntu-amd64-nvml

# Build Ubuntu 24.04 amd64 with AMD ROCm SMI
make docker-build-ubuntu-amd64-rsmi

# Build Rocky 9 amd64 with NVIDIA NVML
make docker-build-rocky-amd64-nvml

# Build Ubuntu 24.04 arm64 with NVIDIA NVML (via QEMU)
make docker-build-ubuntu-arm64-nvml

# Build all variants
make docker-build-all
```

### Output naming

```
output/slurm-25.11.4-ubuntu2404-amd64-nvml13.tar.gz
output/slurm-25.11.4-ubuntu2404-amd64-rsmi6.2.4.tar.gz
output/slurm-25.11.4-rocky9-amd64-nvml13.tar.gz
```

### Custom versions

```bash
# Override Slurm version
make docker-build-ubuntu-amd64-nvml SLURM_VERSION=25.11.4 SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c

# Override GPU library versions
make docker-build-ubuntu-amd64-nvml CUDA_VERSION=12
make docker-build-ubuntu-amd64-rsmi ROCM_VERSION=6.2.4
```

### Prerequisites

- Docker with buildx plugin
- For arm64 builds: QEMU user-static (registered automatically via `docker-setup`)

## Direct builds (inside a container or build host)

These targets run directly on the host and are used internally by the Docker builds.

```bash
make build-ubuntu   # Build .deb packages (requires Ubuntu/Debian)
make build-rocky    # Build .rpm packages (requires Rocky/RHEL 9)
```

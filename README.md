# Slurm Package Builder

This repo contains the scripts for building Slurm packages for Rocky Linux and Ubuntu, with support for GPU detection using ROCm SMI and NVIDIA ML.

## Docker builds (recommended)

Build packages inside Docker containers targeting specific distros and architectures. Packages are output to `./output/<distro>-<arch>/`.

```bash
# Build Ubuntu 24.04 amd64 .deb packages
make docker-build-ubuntu-amd64

# Build Ubuntu 24.04 arm64 .deb packages (via QEMU emulation)
make docker-build-ubuntu-arm64

# Build Rocky 9 amd64 .rpm packages
make docker-build-rocky-amd64

# Build all targets
make docker-build-all

# Clean output and remove buildx builder
make docker-clean
```

### Prerequisites

- Docker with buildx plugin
- For arm64 builds: QEMU user-static (registered automatically via `docker-setup`)

### Custom Slurm version

```bash
make docker-build-ubuntu-amd64 SLURM_VERSION=25.11.4 SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
```

## Direct builds (inside a container or build host)

These targets run directly on the host and are used internally by the Docker builds.

```bash
make build-ubuntu   # Build .deb packages (requires Ubuntu/Debian)
make build-rocky    # Build .rpm packages (requires Rocky/RHEL 9)
```

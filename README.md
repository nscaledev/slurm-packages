# Slurm Package Builder

Build Slurm and Pyxis packages for Rocky Linux and Ubuntu with GPU plugin support (NVIDIA NVML and AMD ROCm SMI).

Both Ubuntu and Rocky builds are feature-identical (mysql, hwloc, numa, pmix, slurmrestd, lua, yaml, jwt, hdf5, freeipmi, rdkafka, rrdtool) to support mixed-OS clusters. amd64 builds include both NVML and ROCm SMI GPU plugins; arm64 builds include NVML only (ROCm is x86_64-only).

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

### Configurable versions

| Variable | Default | Description |
|---|---|---|
| `SLURM_VERSION` | 25.11.4 | Slurm source version |
| `SLURM_MD5SUM` | fc759abe... | Source tarball MD5 checksum |
| `CUDA_VERSION` | 13-1 | NVIDIA NVML dev headers version |
| `ROCM_VERSION` | 6.4.2 | AMD ROCm SMI version |
| `PYXIS_VERSION` | 0.23.0 | NVIDIA Pyxis SPANK plugin version |
| `UBUNTU_VERSION` | 24.04 | Ubuntu base image tag |
| `ROCKY_VERSION` | 9.3 | Rocky Linux base image tag |
| `PKG_RELEASE` | 1 | Package revision number (auto-incremented in CI) |

```bash
make docker-build-ubuntu-amd64 SLURM_VERSION=25.11.4 SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
make docker-build-ubuntu-amd64 CUDA_VERSION=13-1 ROCM_VERSION=6.4.2
make docker-build-pyxis-ubuntu-amd64 PYXIS_VERSION=0.23.0
```

### Output naming

Tarballs include the Slurm version, distro, architecture, and GPU library versions:

```
slurm-25.11.4-ubuntu2404-amd64-cuda13-1-rocm6.4.2.tar.gz
slurm-25.11.4-ubuntu2404-arm64-cuda13-1.tar.gz
slurm-25.11.4-rocky93-amd64-cuda13-1-rocm6.4.2.tar.gz
pyxis-0.23.0-ubuntu2404-amd64-slurm25.11.4.tar.gz
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

The `release.yml` workflow is triggered manually via **workflow_dispatch** with all versions as inputs. Enter `false` for Ubuntu or Rocky version to skip those builds.

### Build pipeline

1. **matrix-setup** — Calculates next package release number from existing releases, generates build matrices
2. **build-slurm** — Builds all Slurm targets in parallel (native arm64 runners for arm64 builds)
3. **build-pyxis** — Builds Pyxis against each Slurm target (depends on build-slurm)
4. **release** — Creates a draft GitHub release with all successful artifacts

### Release versioning

Release tags follow semver: `v25.11.4-1`, `v25.11.4-2`, etc. The build number auto-increments and matches the package revision inside the .deb/.rpm files, so `v25.11.4-2` produces packages versioned `25.11.4-2` (deb) and `25.11.4-2.el9` (rpm).

ARG ROCKY_VERSION=9.3
FROM rockylinux:${ROCKY_VERSION} AS build

ARG SLURM_VERSION=25.11.4
ARG SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
ARG ROCKY_VERSION
ARG CUDA_VERSION
ARG ROCM_VERSION

# Install repos
RUN dnf install -y epel-release dnf-plugins-core && \
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    dnf install -y https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/rhel/${ROCKY_VERSION}/amdgpu-install-6.2.60204-1.el9.noarch.rpm

# Install build dependencies
RUN dnf install -y --enablerepo=devel --enablerepo=crb \
      @Development\ Tools \
      bzip2-devel \
      cuda-nvml-devel-${CUDA_VERSION} \
      dbus-devel \
      freeipmi-devel \
      hdf5-devel \
      http-parser-devel \
      hwloc-devel \
      json-c-devel \
      libcurl-devel \
      libjwt-devel \
      librdkafka-devel \
      libyaml-devel \
      lua-devel \
      make \
      mariadb-devel \
      munge-devel \
      munge-libs \
      numactl-devel \
      openssl-devel \
      pam-devel \
      perl-ExtUtils-MakeMaker \
      pmix-devel \
      procps \
      readline-devel \
      rocm-smi-lib \
      rpm-build \
      rrdtool-devel \
      systemd \
      systemd-rpm-macros

# Symlink NVML headers/libs to standard paths so Slurm configure can find them
RUN CUDA_MAJ_MIN=$(echo "${CUDA_VERSION}" | tr '-' '.') && \
    ln -s /usr/local/cuda-${CUDA_MAJ_MIN}/targets/x86_64-linux/include/nvml.h /usr/include/nvml.h && \
    ln -s /usr/local/cuda-${CUDA_MAJ_MIN}/targets/x86_64-linux/lib/stubs/libnvidia-ml.so /usr/lib64/libnvidia-ml.so

WORKDIR /workspace
COPY Makefile .

ENV BUILD_DIR=/build
RUN mkdir -p /build /output

RUN make build-rocky \
      SLURM_VERSION=${SLURM_VERSION} \
      SLURM_MD5SUM=${SLURM_MD5SUM} \
      BUILD_DIR=/build

RUN cp ~/rpmbuild/RPMS/*/*.rpm /output/

FROM scratch AS export
COPY --from=build /output/ /

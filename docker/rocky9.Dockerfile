FROM rockylinux:9 AS build

ARG SLURM_VERSION=25.11.4
ARG SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
ARG GPU
ARG CUDA_VERSION
ARG ROCM_VERSION

# Install repos
RUN dnf install -y epel-release dnf-plugins-core

# NVIDIA repo (only when building with nvml)
RUN if [ "${GPU}" = "nvml" ]; then \
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo; \
    fi

# AMD repo (only when building with rsmi)
RUN if [ "${GPU}" = "rsmi" ]; then \
      dnf install -y https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/rhel/9.3/amdgpu-install-6.2.60204-1.el9.noarch.rpm; \
    fi

# Install build dependencies
RUN dnf install -y --enablerepo=devel --enablerepo=crb \
      @Development\ Tools \
      bzip2-devel \
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
      rpm-build \
      rrdtool-devel \
      systemd \
      systemd-rpm-macros

# GPU libraries
RUN if [ "${GPU}" = "nvml" ]; then \
      dnf install -y cuda-nvml-devel-${CUDA_VERSION}; \
    elif [ "${GPU}" = "rsmi" ]; then \
      dnf install -y --enablerepo=devel --enablerepo=crb rocm-smi-lib; \
    fi

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

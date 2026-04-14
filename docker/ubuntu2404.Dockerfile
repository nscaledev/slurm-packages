FROM ubuntu:24.04 AS build

ARG SLURM_VERSION=25.11.4
ARG SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
ARG GPU
ARG CUDA_VERSION
ARG ROCM_VERSION
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Install build tooling and base dependencies
RUN apt-get update && apt-get -y upgrade && \
    ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime && \
    apt-get -y install tzdata && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt-get -y install \
      bc \
      build-essential \
      bzip2 \
      curl \
      devscripts \
      equivs \
      fakeroot \
      lsb-release \
      pkg-config

# NVIDIA CUDA repo + NVML dev headers
RUN if [ "${GPU}" = "nvml" ]; then \
      if [ "${TARGETARCH}" = "arm64" ]; then \
        REPO_ARCH=sbsa; \
      else \
        REPO_ARCH=x86_64; \
      fi && \
      curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/${REPO_ARCH}/3bf863cc.pub \
        | gpg --dearmor -o /usr/share/keyrings/cuda-archive-keyring.gpg && \
      echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/${REPO_ARCH}/ /" \
        > /etc/apt/sources.list.d/cuda.list && \
      apt-get update && \
      apt-get -y install cuda-nvml-dev-${CUDA_VERSION}; \
    fi

# AMD ROCm SMI
RUN if [ "${GPU}" = "rsmi" ]; then \
      apt-get -y install librocm-smi-dev; \
    fi

WORKDIR /workspace
COPY Makefile .

ENV BUILD_DIR=/build
RUN mkdir -p /build /output

RUN make build-ubuntu \
      SLURM_VERSION=${SLURM_VERSION} \
      SLURM_MD5SUM=${SLURM_MD5SUM} \
      BUILD_DIR=/build

RUN cp /build/*.deb /output/

FROM scratch AS export
COPY --from=build /output/ /

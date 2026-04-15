ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION} AS build

ARG SLURM_VERSION=25.11.4
ARG SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
ARG TARGETARCH
ARG UBUNTU_VERSION
ARG CUDA_VERSION
ARG ROCM_VERSION

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
      gnupg \
      lsb-release \
      pkg-config \
      wget

# AMD ROCm repo + SMI (amd64 only)
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
      CODENAME=$(. /etc/os-release && echo ${VERSION_CODENAME}) && \
      wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor > /etc/apt/keyrings/rocm.gpg && \
      echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${CODENAME} main" \
        > /etc/apt/sources.list.d/rocm.list && \
      apt-get update && \
      apt-get -y install rocm-smi-lib; \
    fi

# NVIDIA NVML (amd64 and arm64)
RUN UBUNTU_SHORT=$(echo "${UBUNTU_VERSION}" | tr -d '.') && \
    if [ "${TARGETARCH}" = "arm64" ]; then \
      REPO_ARCH=sbsa; CUDA_ARCH=aarch64-linux; \
    else \
      REPO_ARCH=x86_64; CUDA_ARCH=x86_64-linux; \
    fi && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_SHORT}/${REPO_ARCH}/3bf863cc.pub \
      | gpg --dearmor -o /usr/share/keyrings/cuda-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_SHORT}/${REPO_ARCH}/ /" \
      > /etc/apt/sources.list.d/cuda.list && \
    apt-get update && \
    apt-get -y install cuda-nvml-dev-${CUDA_VERSION} && \
    CUDA_MAJ_MIN=$(echo "${CUDA_VERSION}" | tr '-' '.') && \
    ln -s /usr/local/cuda-${CUDA_MAJ_MIN}/targets/${CUDA_ARCH}/include/nvml.h /usr/include/nvml.h && \
    ln -s /usr/local/cuda-${CUDA_MAJ_MIN}/targets/${CUDA_ARCH}/lib/stubs/libnvidia-ml.so /usr/lib/libnvidia-ml.so

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

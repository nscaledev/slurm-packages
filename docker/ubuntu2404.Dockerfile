FROM ubuntu:24.04 AS build

ARG SLURM_VERSION=25.11.4
ARG SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c
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

# GPU libraries (amd64 only)
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
      apt-get -y install librocm-smi-dev libnvidia-ml-dev; \
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

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION} AS build

ARG SLURM_VERSION=25.11.4
ARG PYXIS_VERSION=0.23.0
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Install build tooling
RUN apt-get update && apt-get -y install \
      build-essential \
      curl \
      debhelper \
      devscripts \
      git \
      lsb-release

# Install Slurm packages from the previous build
COPY slurm-debs/ /tmp/slurm-debs/
RUN apt-get -y install /tmp/slurm-debs/*.deb || true && \
    apt-get -y --fix-broken install && \
    rm -rf /tmp/slurm-debs

# Clone and build Pyxis
RUN git clone --depth 1 --branch v${PYXIS_VERSION} https://github.com/NVIDIA/pyxis.git /build/pyxis

WORKDIR /build/pyxis

RUN make orig && make deb

RUN mkdir -p /output && \
    cp /build/*.deb /output/

FROM scratch AS export
COPY --from=build /output/ /

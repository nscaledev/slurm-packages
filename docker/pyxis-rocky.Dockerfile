ARG ROCKY_VERSION=9.3
FROM rockylinux:${ROCKY_VERSION} AS build

ARG SLURM_VERSION=25.11.4
ARG PYXIS_VERSION=0.23.0
ARG TARGETARCH

# Install build tooling
RUN dnf install -y \
      gcc \
      git \
      make \
      rpm-build

# Install Slurm dev headers from the previous build
# Force install to skip runtime deps — only headers are needed for compilation
COPY slurm-rpms/ /tmp/slurm-rpms/
RUN rpm -ivh --nodeps /tmp/slurm-rpms/slurm-2*.rpm /tmp/slurm-rpms/slurm-devel-*.rpm && \
    rm -rf /tmp/slurm-rpms

# Verify slurm-devel is installed (pyxis.spec depends on this)
RUN rpm -q slurm-devel

# Clone and build Pyxis
RUN git clone --depth 1 --branch v${PYXIS_VERSION} https://github.com/NVIDIA/pyxis.git /build/pyxis

WORKDIR /build/pyxis

RUN make rpm

RUN mkdir -p /output && \
    cp rpm/RPMS/*/*.rpm /output/

FROM scratch AS export
COPY --from=build /output/ /

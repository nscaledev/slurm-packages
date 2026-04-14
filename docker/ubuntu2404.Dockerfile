FROM ubuntu:24.04 AS build

ARG SLURM_VERSION=25.11.4
ARG SLURM_MD5SUM=fc759abe52f407520b348eac9b887c1c

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

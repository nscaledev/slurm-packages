SHELL := /bin/bash

SLURM_VERSION ?= 25.11.4
SLURM_MD5SUM ?= fc759abe52f407520b348eac9b887c1c
SLURM_TARBALL ?= slurm-$(SLURM_VERSION).tar.bz2
SLURM_SOURCE ?= https://download.schedmd.com/slurm/$(SLURM_TARBALL)

BUILD_DIR ?= /build

.PHONY: default
default: build-ubuntu

.PHONY: fetch-source
fetch-source: $(SLURM_TARBALL)
$(SLURM_TARBALL):
	@mkdir -p $(BUILD_DIR)
	@curl -L $(SLURM_SOURCE) -o $(BUILD_DIR)/$(SLURM_TARBALL)
	@if [[ $$(md5sum $(BUILD_DIR)/$(SLURM_TARBALL) | awk '{print $$1}') != $(SLURM_MD5SUM) ]]; then \
		echo "$(SLURM_TARBALL) md5sum does not match expected value: $(SLURM_MD5SUM)"; \
	exit 1; \
	fi

.PHONY: build-ubuntu
build-ubuntu: fetch-source
	@tar -C $(BUILD_DIR) -xf $(BUILD_DIR)/$(SLURM_TARBALL)
	@pushd $(BUILD_DIR)/slurm-$(SLURM_VERSION) && \
		mk-build-deps -ir --tool='apt-get -qq -y -o Debug::pkgProblemResolver=yes --no-install-recommends' debian/control && \
		debuild -b -uc -us

.PHONY: build-rocky
build-rocky: fetch-source
	@rpmbuild -ta $(BUILD_DIR)/$(SLURM_TARBALL) \
		--with mysql \
		--with hwloc \
		--with numa \
		--with pmix \
		--with slurmrestd \
		--with lua \
		--with yaml \
		--with jwt \
		--with hdf5 \
		--with freeipmi \
		--with rdkafka \
		--with rrdtool

# === Docker build targets ===

DOCKER_BUILDX_BUILDER ?= slurm-builder
OUTPUT_DIR ?= ./output

.PHONY: docker-setup
docker-setup:
	@docker buildx inspect $(DOCKER_BUILDX_BUILDER) >/dev/null 2>&1 || \
		docker buildx create --name $(DOCKER_BUILDX_BUILDER) --driver docker-container --bootstrap
	@docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true

.PHONY: docker-build-ubuntu-amd64
docker-build-ubuntu-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)/ubuntu2404-amd64
	docker buildx build \
		--builder $(DOCKER_BUILDX_BUILDER) \
		--platform linux/amd64 \
		--file docker/ubuntu2404.Dockerfile \
		--build-arg SLURM_VERSION=$(SLURM_VERSION) \
		--build-arg SLURM_MD5SUM=$(SLURM_MD5SUM) \
		--target export \
		--output type=local,dest=$(OUTPUT_DIR)/ubuntu2404-amd64 \
		.

.PHONY: docker-build-ubuntu-arm64
docker-build-ubuntu-arm64: docker-setup
	@mkdir -p $(OUTPUT_DIR)/ubuntu2404-arm64
	docker buildx build \
		--builder $(DOCKER_BUILDX_BUILDER) \
		--platform linux/arm64 \
		--file docker/ubuntu2404.Dockerfile \
		--build-arg SLURM_VERSION=$(SLURM_VERSION) \
		--build-arg SLURM_MD5SUM=$(SLURM_MD5SUM) \
		--target export \
		--output type=local,dest=$(OUTPUT_DIR)/ubuntu2404-arm64 \
		.

.PHONY: docker-build-rocky-amd64
docker-build-rocky-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)/rocky9-amd64
	docker buildx build \
		--builder $(DOCKER_BUILDX_BUILDER) \
		--platform linux/amd64 \
		--file docker/rocky9.Dockerfile \
		--build-arg SLURM_VERSION=$(SLURM_VERSION) \
		--build-arg SLURM_MD5SUM=$(SLURM_MD5SUM) \
		--target export \
		--output type=local,dest=$(OUTPUT_DIR)/rocky9-amd64 \
		.

.PHONY: docker-build-all
docker-build-all: docker-build-ubuntu-amd64 docker-build-ubuntu-arm64 docker-build-rocky-amd64

.PHONY: docker-clean
docker-clean:
	rm -rf $(OUTPUT_DIR)
	docker buildx rm $(DOCKER_BUILDX_BUILDER) 2>/dev/null || true

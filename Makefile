SHELL := /bin/bash

SLURM_VERSION ?= 25.11.4
SLURM_MD5SUM ?= fc759abe52f407520b348eac9b887c1c
SLURM_TARBALL ?= slurm-$(SLURM_VERSION).tar.bz2
SLURM_SOURCE ?= https://download.schedmd.com/slurm/$(SLURM_TARBALL)

BUILD_DIR ?= /build

# OS image versions
UBUNTU_VERSION ?= 24.04
ROCKY_VERSION ?= 9.3

# GPU library versions
CUDA_VERSION ?= 13-2
ROCM_VERSION ?= 6.2.4

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

# Helper to run a docker buildx build and package the output as a tarball
# $(1) = Dockerfile, $(2) = platform, $(3) = tarball name
define docker-build
	$(eval TMPDIR := $(shell mktemp -d))
	docker buildx build \
		--builder $(DOCKER_BUILDX_BUILDER) \
		--platform $(2) \
		--file $(1) \
		--build-arg SLURM_VERSION=$(SLURM_VERSION) \
		--build-arg SLURM_MD5SUM=$(SLURM_MD5SUM) \
		--build-arg CUDA_VERSION=$(CUDA_VERSION) \
		--build-arg ROCM_VERSION=$(ROCM_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg ROCKY_VERSION=$(ROCKY_VERSION) \
		--target export \
		--output type=local,dest=$(TMPDIR) \
		.
	@tar -czf $(OUTPUT_DIR)/$(3) -C $(TMPDIR) .
	@rm -rf $(TMPDIR)
endef

.PHONY: docker-build-ubuntu-amd64
docker-build-ubuntu-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/ubuntu2404.Dockerfile,linux/amd64,slurm-$(SLURM_VERSION)-ubuntu2404-amd64.tar.gz)

.PHONY: docker-build-ubuntu-arm64
docker-build-ubuntu-arm64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/ubuntu2404.Dockerfile,linux/arm64,slurm-$(SLURM_VERSION)-ubuntu2404-arm64.tar.gz)

.PHONY: docker-build-rocky-amd64
docker-build-rocky-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/rocky9.Dockerfile,linux/amd64,slurm-$(SLURM_VERSION)-rocky9-amd64.tar.gz)

.PHONY: docker-build-all
docker-build-all: docker-build-ubuntu-amd64 docker-build-ubuntu-arm64 docker-build-rocky-amd64

.PHONY: docker-clean
docker-clean:
	rm -rf $(OUTPUT_DIR)
	docker buildx rm $(DOCKER_BUILDX_BUILDER) 2>/dev/null || true

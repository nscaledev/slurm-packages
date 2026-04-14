SHELL := /bin/bash

SLURM_VERSION ?= 25.11.4
SLURM_MD5SUM ?= fc759abe52f407520b348eac9b887c1c
SLURM_TARBALL ?= slurm-$(SLURM_VERSION).tar.bz2
SLURM_SOURCE ?= https://download.schedmd.com/slurm/$(SLURM_TARBALL)

BUILD_DIR ?= /build

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
# $(1) = Dockerfile, $(2) = platform, $(3) = gpu type, $(4) = tarball name
define docker-build
	$(eval TMPDIR := $(shell mktemp -d))
	docker buildx build \
		--builder $(DOCKER_BUILDX_BUILDER) \
		--platform $(2) \
		--file $(1) \
		--build-arg SLURM_VERSION=$(SLURM_VERSION) \
		--build-arg SLURM_MD5SUM=$(SLURM_MD5SUM) \
		--build-arg GPU=$(3) \
		--build-arg CUDA_VERSION=$(CUDA_VERSION) \
		--build-arg ROCM_VERSION=$(ROCM_VERSION) \
		--target export \
		--output type=local,dest=$(TMPDIR) \
		.
	@tar -czf $(OUTPUT_DIR)/$(4) -C $(TMPDIR) .
	@rm -rf $(TMPDIR)
endef

# Ubuntu 24.04 amd64
.PHONY: docker-build-ubuntu-amd64-nvml
docker-build-ubuntu-amd64-nvml: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/ubuntu2404.Dockerfile,linux/amd64,nvml,slurm-$(SLURM_VERSION)-ubuntu2404-amd64-nvml$(CUDA_VERSION).tar.gz)

.PHONY: docker-build-ubuntu-amd64-rsmi
docker-build-ubuntu-amd64-rsmi: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/ubuntu2404.Dockerfile,linux/amd64,rsmi,slurm-$(SLURM_VERSION)-ubuntu2404-amd64-rsmi$(ROCM_VERSION).tar.gz)

# Ubuntu 24.04 arm64
.PHONY: docker-build-ubuntu-arm64-nvml
docker-build-ubuntu-arm64-nvml: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/ubuntu2404.Dockerfile,linux/arm64,nvml,slurm-$(SLURM_VERSION)-ubuntu2404-arm64-nvml$(CUDA_VERSION).tar.gz)

.PHONY: docker-build-ubuntu-arm64-rsmi
docker-build-ubuntu-arm64-rsmi: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/ubuntu2404.Dockerfile,linux/arm64,rsmi,slurm-$(SLURM_VERSION)-ubuntu2404-arm64-rsmi$(ROCM_VERSION).tar.gz)

# Rocky 9 amd64
.PHONY: docker-build-rocky-amd64-nvml
docker-build-rocky-amd64-nvml: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/rocky9.Dockerfile,linux/amd64,nvml,slurm-$(SLURM_VERSION)-rocky9-amd64-nvml$(CUDA_VERSION).tar.gz)

.PHONY: docker-build-rocky-amd64-rsmi
docker-build-rocky-amd64-rsmi: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/rocky9.Dockerfile,linux/amd64,rsmi,slurm-$(SLURM_VERSION)-rocky9-amd64-rsmi$(ROCM_VERSION).tar.gz)

# Convenience targets
.PHONY: docker-build-all-nvml
docker-build-all-nvml: docker-build-ubuntu-amd64-nvml docker-build-ubuntu-arm64-nvml docker-build-rocky-amd64-nvml

.PHONY: docker-build-all-rsmi
docker-build-all-rsmi: docker-build-ubuntu-amd64-rsmi docker-build-ubuntu-arm64-rsmi docker-build-rocky-amd64-rsmi

.PHONY: docker-build-all
docker-build-all: docker-build-all-nvml docker-build-all-rsmi

.PHONY: docker-clean
docker-clean:
	rm -rf $(OUTPUT_DIR)
	docker buildx rm $(DOCKER_BUILDX_BUILDER) 2>/dev/null || true

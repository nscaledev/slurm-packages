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
CUDA_VERSION ?= 13-1
ROCM_VERSION ?= 6.4.2

# Pyxis
PYXIS_VERSION ?= 0.23.0

# Package release number (auto-incremented in CI)
PKG_RELEASE ?= 1

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
	@sed -i '1s/-[0-9]\+)/-$(PKG_RELEASE))/' $(BUILD_DIR)/slurm-$(SLURM_VERSION)/debian/changelog
	@pushd $(BUILD_DIR)/slurm-$(SLURM_VERSION) && \
		mk-build-deps -ir --tool='apt-get -qq -y -o Debug::pkgProblemResolver=yes --no-install-recommends' debian/control && \
		DEB_BUILD_OPTIONS="parallel=$$(nproc)" debuild -b -uc -us

.PHONY: build-rocky
build-rocky: fetch-source
	@tar -C $(BUILD_DIR) -xf $(BUILD_DIR)/$(SLURM_TARBALL)
	@sed -i 's/^%define rel\t[0-9]*/%define rel\t$(PKG_RELEASE)/' $(BUILD_DIR)/slurm-$(SLURM_VERSION)/slurm.spec
	@SRCDIR=slurm-$(SLURM_VERSION); \
	if [ "$(PKG_RELEASE)" != "1" ]; then \
		mv $(BUILD_DIR)/$${SRCDIR} $(BUILD_DIR)/$${SRCDIR}-$(PKG_RELEASE); \
		SRCDIR=$${SRCDIR}-$(PKG_RELEASE); \
	fi; \
	tar -C $(BUILD_DIR) -cjf $(BUILD_DIR)/$${SRCDIR}.tar.bz2 $${SRCDIR}; \
	rpmbuild -ta $(BUILD_DIR)/$${SRCDIR}.tar.bz2 \
		--define "_smp_mflags -j$$(nproc)" \
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

# In CI (e.g. GitHub Actions), buildx and QEMU are set up by dedicated actions.
# Set CI=1 to skip docker-setup and use the default builder.
CI ?= 0

.PHONY: docker-setup
docker-setup:
ifneq ($(CI),1)
	@docker buildx inspect $(DOCKER_BUILDX_BUILDER) >/dev/null 2>&1 || \
		docker buildx create --name $(DOCKER_BUILDX_BUILDER) --driver docker-container --bootstrap
	@docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true
endif

# Helper to run a docker buildx build and package the output as a tarball
# $(1) = Dockerfile, $(2) = platform, $(3) = tarball base name (rocm version appended automatically)
define docker-build
	$(eval TMPDIR := $(shell mktemp -d))
	docker buildx build \
		$(if $(filter 1,$(CI)),,--builder $(DOCKER_BUILDX_BUILDER)) \
		--platform $(2) \
		--file $(1) \
		--build-arg SLURM_VERSION=$(SLURM_VERSION) \
		--build-arg SLURM_MD5SUM=$(SLURM_MD5SUM) \
		--build-arg CUDA_VERSION=$(CUDA_VERSION) \
		--build-arg ROCM_VERSION=$(ROCM_VERSION) \
		--build-arg PKG_RELEASE=$(PKG_RELEASE) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg ROCKY_VERSION=$(ROCKY_VERSION) \
		--target export \
		--output type=local,dest=$(TMPDIR) \
		.
	@tar -czf $(OUTPUT_DIR)/$(3).tar.gz -C $(TMPDIR) .
	@rm -rf $(TMPDIR)
endef

.PHONY: docker-build-ubuntu-amd64
docker-build-ubuntu-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/slurm-ubuntu.Dockerfile,linux/amd64,slurm-$(SLURM_VERSION)-ubuntu$(subst .,,$(UBUNTU_VERSION))-amd64-cuda$(CUDA_VERSION)-rocm$(ROCM_VERSION))

.PHONY: docker-build-ubuntu-arm64
docker-build-ubuntu-arm64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/slurm-ubuntu.Dockerfile,linux/arm64,slurm-$(SLURM_VERSION)-ubuntu$(subst .,,$(UBUNTU_VERSION))-arm64-cuda$(CUDA_VERSION))

.PHONY: docker-build-rocky-amd64
docker-build-rocky-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/slurm-rocky.Dockerfile,linux/amd64,slurm-$(SLURM_VERSION)-rocky$(subst .,,$(ROCKY_VERSION))-amd64-cuda$(CUDA_VERSION)-rocm$(ROCM_VERSION))

.PHONY: docker-build-rocky-arm64
docker-build-rocky-arm64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call docker-build,docker/slurm-rocky.Dockerfile,linux/arm64,slurm-$(SLURM_VERSION)-rocky$(subst .,,$(ROCKY_VERSION))-arm64-cuda$(CUDA_VERSION))

.PHONY: docker-build-all
docker-build-all: docker-build-ubuntu-amd64 docker-build-ubuntu-arm64 docker-build-rocky-amd64 docker-build-rocky-arm64

# === Pyxis build targets ===
# These require the corresponding Slurm build to have completed first.
# $(1) = Dockerfile, $(2) = platform, $(3) = slurm tarball glob, $(4) = pkg subdir, $(5) = output tarball base
define pyxis-build
	$(eval CTXDIR := $(shell mktemp -d))
	$(eval OUTDIR := $(shell mktemp -d))
	@mkdir -p $(CTXDIR)/$(4)
	@tar -xzf $$(ls $(OUTPUT_DIR)/$(3) | head -1) -C $(CTXDIR)/$(4)
	@cp $(1) $(CTXDIR)/Dockerfile
	docker buildx build \
		$(if $(filter 1,$(CI)),,--builder $(DOCKER_BUILDX_BUILDER)) \
		--platform $(2) \
		--file $(CTXDIR)/Dockerfile \
		--build-arg SLURM_VERSION=$(SLURM_VERSION) \
		--build-arg PYXIS_VERSION=$(PYXIS_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg ROCKY_VERSION=$(ROCKY_VERSION) \
		--target export \
		--output type=local,dest=$(OUTDIR) \
		$(CTXDIR)
	@tar -czf $(OUTPUT_DIR)/$(5).tar.gz -C $(OUTDIR) .
	@rm -rf $(CTXDIR) $(OUTDIR)
endef

.PHONY: docker-build-pyxis-ubuntu-amd64
docker-build-pyxis-ubuntu-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call pyxis-build,docker/pyxis-ubuntu.Dockerfile,linux/amd64,slurm-$(SLURM_VERSION)-ubuntu$(subst .,,$(UBUNTU_VERSION))-amd64-*.tar.gz,slurm-debs,pyxis-$(PYXIS_VERSION)-ubuntu$(subst .,,$(UBUNTU_VERSION))-amd64-slurm$(SLURM_VERSION))

.PHONY: docker-build-pyxis-ubuntu-arm64
docker-build-pyxis-ubuntu-arm64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call pyxis-build,docker/pyxis-ubuntu.Dockerfile,linux/arm64,slurm-$(SLURM_VERSION)-ubuntu$(subst .,,$(UBUNTU_VERSION))-arm64-*.tar.gz,slurm-debs,pyxis-$(PYXIS_VERSION)-ubuntu$(subst .,,$(UBUNTU_VERSION))-arm64-slurm$(SLURM_VERSION))

.PHONY: docker-build-pyxis-rocky-amd64
docker-build-pyxis-rocky-amd64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call pyxis-build,docker/pyxis-rocky.Dockerfile,linux/amd64,slurm-$(SLURM_VERSION)-rocky$(subst .,,$(ROCKY_VERSION))-amd64-*.tar.gz,slurm-rpms,pyxis-$(PYXIS_VERSION)-rocky$(subst .,,$(ROCKY_VERSION))-amd64-slurm$(SLURM_VERSION))

.PHONY: docker-build-pyxis-rocky-arm64
docker-build-pyxis-rocky-arm64: docker-setup
	@mkdir -p $(OUTPUT_DIR)
	$(call pyxis-build,docker/pyxis-rocky.Dockerfile,linux/arm64,slurm-$(SLURM_VERSION)-rocky$(subst .,,$(ROCKY_VERSION))-arm64-*.tar.gz,slurm-rpms,pyxis-$(PYXIS_VERSION)-rocky$(subst .,,$(ROCKY_VERSION))-arm64-slurm$(SLURM_VERSION))

.PHONY: docker-build-pyxis-all
docker-build-pyxis-all: docker-build-pyxis-ubuntu-amd64 docker-build-pyxis-ubuntu-arm64 docker-build-pyxis-rocky-amd64 docker-build-pyxis-rocky-arm64

.PHONY: docker-clean
docker-clean:
	rm -rf $(OUTPUT_DIR)
	docker buildx rm $(DOCKER_BUILDX_BUILDER) 2>/dev/null || true

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
	@sudo apt -y update
	@sudo apt -y upgrade
	@sudo ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
	@sudo DEBIAN_FRONTEND=noninteractive apt -y install tzdata
	@sudo dpkg-reconfigure --frontend noninteractive tzdata
	@sudo apt -y install bc build-essential curl devscripts fakeroot equivs lsb-release pkg-config
	@if [ "$$(dpkg --print-architecture)" = "amd64" ]; then \
		sudo apt -y install librocm-smi-dev libnvidia-ml-dev; \
	fi
	@tar -C $(BUILD_DIR) -xf $(BUILD_DIR)/$(SLURM_TARBALL)
	@pushd $(BUILD_DIR)/slurm-$(SLURM_VERSION) && \
		sudo mk-build-deps -ir --tool='apt-get -qq -y -o Debug::pkgProblemResolver=yes --no-install-recommends' debian/control && \
		debuild -b -uc -us

.PHONY: build-rocky
build-rocky: fetch-source
	@dnf install -y https://repo.radeon.com/amdgpu-install/6.2.4/rhel/9.3/amdgpu-install-6.2.60204-1.el9.noarch.rpm
	@dnf install -y --enablerepo=devel --enablerepo=crb \
		@Development\ Tools \
		bzip2-devel \
		dbus-devel \
		http-parser-devel \
		hwloc-devel \
		json-c-devel \
		libyaml-devel \
		lua-devel \
		mariadb-devel \
		munge-devel \
		munge-libs \
		numactl-devel \
		openssl-devel \
		pam-devel \
		perl-ExtUtils-MakeMaker \
		pmix-devel \
		procps \
		readline-devel \
		rocm-smi-lib \
		rpm-build \
		systemd \
		systemd-rpm-macros
	@rpmbuild -ta $(BUILD_DIR)/$(SLURM_TARBALL) \
		--with mysql \
		--with hwloc \
		--with numa \
		--with pmix \
		--with slurmrestd \
		--with lua \
		--with yaml

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

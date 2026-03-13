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
	@sudo apt -y install librocm-smi-dev libnvidia-ml-dev
	@tar -C $(BUILD_DIR) -xf $(BUILD_DIR)/$(SLURM_TARBALL)
	@pushd $(BUILD_DIR)/slurm-$(SLURM_VERSION) && \
		sudo mk-build-deps -ir --tool='apt-get -qq -y -o Debug::pkgProblemResolver=yes --no-install-recommends' debian/control && \
		debuild -b -uc -us

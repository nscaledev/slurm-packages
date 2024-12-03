SHELL := /bin/bash

SLURM_VERSION ?= 24.05.4
SLURM_MD5SUM ?= 3c96457c564990db9a6ee5d81b225587
SLURM_TARBALL ?= slurm-$(SLURM_VERSION).tar.bz2
SLURM_SOURCE ?= https://download.schedmd.com/slurm/$(SLURM_TARBALL)

BUILD_DIR ?= /build

.PHONY: default
default:
	@echo "No target specified"

.PHONY: fetch-source
fetch-source: $(SLURM_TARBALL)
$(SLURM_TARBALL):
	@mkdir -p $(BUILD_DIR)
	@curl -L $(SLURM_SOURCE) -o $(BUILD_DIR)/$(SLURM_TARBALL)
	@if [[ $$(md5sum $(BUILD_DIR)/$(SLURM_TARBALL) | awk '{print $$1}') != $(SLURM_MD5SUM) ]]; then \
		echo "$(SLURM_TARBALL) md5sum does not match expected value: $(SLURM_MD5SUM)"; \
	exit 1; \
	fi

.PHONY: build-rocky
build-rocky: fetch-source
	@dnf install -y https://repo.radeon.com/amdgpu-install/6.2.4/rhel/9.3/amdgpu-install-6.2.60204-1.el9.noarch.rpm
	@dnf install -y --enablerepo=devel --enablerepo=crb \
		@Development\ Tools \
		bzip2-devel \
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

.PHONY: build-ubuntu
build-ubuntu: fetch-source
	@apt -y update && apt -y upgrade
	@ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
	@DEBIAN_FRONTEND=noninteractive apt -y install tzdata
	@dpkg-reconfigure --frontend noninteractive tzdata
	@apt -y install build-essential curl devscripts fakeroot equivs lsb-release
	@curl -L https://repo.radeon.com/amdgpu-install/6.2.4/ubuntu/$$(lsb_release -sc 2>/dev/null)/amdgpu-install_6.2.60204-1_all.deb -o /tmp/amdgpu-install.deb
	@apt -y install /tmp/amdgpu-install.deb
	@apt -y update
	@apt -y install rocm-smi-lib
	@tar -C $(BUILD_DIR) -xf $(BUILD_DIR)/$(SLURM_TARBALL)
	@pushd $(BUILD_DIR)/slurm-$(SLURM_VERSION) && \
		yes | mk-build-deps -i debian/control && \
		debuild -b -uc -us

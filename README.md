# Slurm Package Builder

This repo contains the scripts for building Slurm packages for Rocky Linux and Ubuntu, with support for GPU detection using ROCm SMI

## Building packages

Use the Makefile with targets `make build-rocky` and `make build-ubuntu`. Slurm version 24.05.4 is built by default, but this can be changed by setting
the variables `SLURM_VERSION` and `SLURM_MD5SUM`
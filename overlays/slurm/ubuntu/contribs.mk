# Every directory under contribs/ must be listed in exactly one of these.
# CONTRIB_TOOLS are packaged in slurm-smd-contribs. CONTRIB_SKIP are handled by
# the upstream debian/rules or are not command-line tools. A Slurm release that
# adds or removes a contrib directory fails check-contribs until it is sorted here.
CONTRIB_TOOLS := seff sgather sjobexit
CONTRIB_SKIP := lua nss_slurm openlava pam pam_slurm_adopt perlapi pmi pmi2 slurm_completion_help torque

CONTRIBS_DIR := debian/slurm-smd-contribs

.PHONY: check-contribs
check-contribs:
	@sed -n 's/^SUBDIRS *+*= *//p' contribs/Makefile.am | tr -s ' \t' '\n\n' | sed '/^$$/d' | sort -u > debian/contribs.upstream
	@printf '%s\n' $(CONTRIB_TOOLS) $(CONTRIB_SKIP) | sort -u > debian/contribs.known
	@diff -u debian/contribs.known debian/contribs.upstream || { \
		echo "contribs/ no longer matches debian/contribs.mk: add new directories to CONTRIB_TOOLS or CONTRIB_SKIP, drop removed ones"; \
		exit 1; }
	@test -f contribs/sjstat || { echo "contribs/sjstat is gone: update debian/contribs.mk"; exit 1; }

# Install straight into the package directory, so every file a listed contrib
# installs is packaged without keeping a separate .install list in sync.
execute_after_dh_auto_install:
	# An empty _perldir makes seff and sjobexitmod use the system Perl search
	# path, where slurm-smd-libslurm-perl installs Slurm.pm and Slurmdb.pm.
	set -e; for d in $(CONTRIB_TOOLS); do \
		$(MAKE) -C obj-$(DEB_BUILD_GNU_TYPE)/contribs/$$d install DESTDIR=$(CURDIR)/$(CONTRIBS_DIR) _perldir=; \
	done
	install -D -m755 contribs/sjstat $(CONTRIBS_DIR)/usr/bin/sjstat
	mkdir -p $(CONTRIBS_DIR)/usr/share/man/man1
	$(CONTRIBS_DIR)/usr/bin/sjobexitmod --roff > $(CONTRIBS_DIR)/usr/share/man/man1/sjobexitmod.1
	$(CONTRIBS_DIR)/usr/bin/sjstat --roff > $(CONTRIBS_DIR)/usr/share/man/man1/sjstat.1

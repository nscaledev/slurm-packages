# Use the system Perl search path for the packaged Perl API.
# Keep this Architecture: all package independent of the build architecture.

execute_after_dh_auto_install:
	$(MAKE) -C obj-$(DEB_BUILD_GNU_TYPE)/contribs/seff install DESTDIR=$(CURDIR)/debian/tmp _perldir=
	$(MAKE) -C obj-$(DEB_BUILD_GNU_TYPE)/contribs/sjobexit install DESTDIR=$(CURDIR)/debian/tmp _perldir=
	$(MAKE) -C obj-$(DEB_BUILD_GNU_TYPE)/contribs/sgather install DESTDIR=$(CURDIR)/debian/tmp
	install -m755 contribs/sjstat debian/tmp/usr/bin/sjstat
	debian/tmp/usr/bin/sjobexitmod --roff > debian/tmp/usr/share/man/man1/sjobexitmod.1
	debian/tmp/usr/bin/sjstat --roff > debian/tmp/usr/share/man/man1/sjstat.1

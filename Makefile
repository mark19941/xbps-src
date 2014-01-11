# xbps-src toplevel makefile.
#
# MUTABLE VARIABLES (CAN BE OVERRIDEN)
PREFIX  ?= /usr/local
SBINDIR ?= $(PREFIX)/sbin
SHAREDIR ?= $(PREFIX)/share/xbps-src
LIBEXECDIR ?= $(PREFIX)/libexec
ETCDIR  ?= $(PREFIX)/etc/xbps

PRIVILEGED_GROUP ?= xbuilder

# INMUTABLE VARIABLES
VERSION	= 98
GITVER	:= $(shell git rev-parse --short HEAD)
CONF_FILE = xbps-src.conf

CHROOT_C = linux-user-chroot.c
CHROOT_BIN = xbps-src-chroot-helper
CFLAGS += -O2 -Wall -Werror

.PHONY: all clean install uninstall

all:
	sed -e	"s|@@XBPS_INSTALL_PREFIX@@|$(PREFIX)|g"		\
	    -e	"s|@@XBPS_INSTALL_ETCDIR@@|$(ETCDIR)|g"		\
	    -e  "s|@@XBPS_INSTALL_SHAREDIR@@|$(SHAREDIR)|g"	\
	    -e  "s|@@XBPS_INSTALL_SBINDIR@@|$(SBINDIR)|g"	\
	    -e	"s|@@XBPS_INSTALL_LIBEXECDIR@@|$(LIBEXECDIR)|g"	\
	    -e  "s|@@XBPS_SRC_VERSION@@|$(VERSION) ($(GITVER))|g"	\
		xbps-src.sh.in > xbps-src
	$(CC) $(CFLAGS) libexec/$(CHROOT_C) -o libexec/$(CHROOT_BIN)

clean:
	rm -f libexec/xbps-src-chroot-helper
	rm -f xbps-src

install-scripts: all
	install -d $(DESTDIR)$(SBINDIR)
	install -m 755 xbps-src $(DESTDIR)$(SBINDIR)
	install -d $(DESTDIR)$(LIBEXECDIR)
	for f in libexec/*.sh; do	\
		install -m 755 $$f $(DESTDIR)$(LIBEXECDIR)/$$(basename $${f%.sh});	\
	done
	install -m 750 libexec/$(CHROOT_BIN) $(DESTDIR)$(LIBEXECDIR)
	install -d $(DESTDIR)$(SHAREDIR)/shutils
	install -m 644 shutils/*.sh $(DESTDIR)$(SHAREDIR)/shutils
	install -d $(DESTDIR)$(SHAREDIR)/helpers
	install -m 644 helpers/*.sh $(DESTDIR)$(SHAREDIR)/helpers
	install -d $(DESTDIR)$(SHAREDIR)/chroot
	install -m 644 chroot/xbps.conf $(DESTDIR)$(SHAREDIR)/chroot
	install -m 644 chroot/repos-local.conf $(DESTDIR)$(SHAREDIR)/chroot
	install -m 644 chroot/repos-remote.conf $(DESTDIR)$(SHAREDIR)/chroot
	if [ ! -d $(DESTDIR)$(ETCDIR) ]; then           \
		install -d $(DESTDIR)$(ETCDIR);         \
	fi
	if [ ! -f $(DESTDIR)$(ETCDIR)/$(CONF_FILE) ]; then      \
		install -m644 etc/$(CONF_FILE) $(DESTDIR)$(ETCDIR); \
	fi

install: install-scripts
	@echo
	@echo "Applying special perms to $(DESTDIR)$(LIBEXECDIR)/xbps-src-chroot-helper"
	@echo "This is a setgid binary (4750) with group '$(PRIVILEGED_GROUP)'"
	@echo
	chgrp $(PRIVILEGED_GROUP) $(DESTDIR)/$(LIBEXECDIR)/xbps-src-chroot-helper
	chmod 4750 $(DESTDIR)$(LIBEXECDIR)/xbps-src-chroot-helper

uninstall:
	-rm -f $(DESTDIR)$(SBINDIR)/xbps-src
	-rm -f $(DESTDIR)$(LIBEXECDIR)/xbps-src-*
	-rm -rf $(DESTDIR)$(SHAREDIR)/shutils
	-rm -rf $(DESTDIR)$(SHAREDIR)/helpers
	-rm -rf $(DESTDIR)$(SHAREDIR)/chroot

dist:
	@echo "Building distribution tarball for tag: v$(VERSION) ..."
	-@git archive --format=tar --prefix=xbps-src-$(VERSION)/ \
		v$(VERSION) | gzip -9 > ~/xbps-src-$(VERSION).tar.gz

# xbps-src toplevel makefile.
#
PREFIX  ?= /usr/local
SBINDIR ?= $(PREFIX)/sbin
SHAREDIR ?= $(PREFIX)/share/xbps-src
LIBEXECDIR ?= $(PREFIX)/libexec
ETCDIR  ?= $(PREFIX)/etc/xbps

VERSION	= 33
GITVER	:= $(shell git rev-parse HEAD)
CONF_FILE = xbps-src.conf

.PHONY: all
all:
	sed -e	"s|@@XBPS_INSTALL_PREFIX@@|$(PREFIX)|g"		\
	    -e	"s|@@XBPS_INSTALL_ETCDIR@@|$(ETCDIR)|g"		\
	    -e  "s|@@XBPS_INSTALL_SHAREDIR@@|$(SHAREDIR)|g"	\
	    -e  "s|@@XBPS_INSTALL_SBINDIR@@|$(SBINDIR)|g"	\
	    -e	"s|@@XBPS_INSTALL_LIBEXECDIR@@|$(LIBEXECDIR)|g"	\
	    -e  "s|@@XBPS_SRC_VERSION@@|$(VERSION) ($(GITVER))|g"	\
		xbps-src.sh.in > xbps-src

.PHONY: clean
clean:
	rm -f xbps-src

.PHONY: install
install: all
	install -d $(DESTDIR)$(SBINDIR)
	install -m 755 xbps-src $(DESTDIR)$(SBINDIR)
	install -d $(DESTDIR)$(LIBEXECDIR)
	install -m 755 libexec/xbps-src-doinst-helper $(DESTDIR)$(LIBEXECDIR)
	install -d $(DESTDIR)$(SHAREDIR)/shutils
	install -m 644 shutils/*.sh $(DESTDIR)$(SHAREDIR)/shutils
	install -d $(DESTDIR)$(SHAREDIR)/helpers
	install -m 644 helpers/*.sh $(DESTDIR)$(SHAREDIR)/helpers
	install -d $(DESTDIR)$(SHAREDIR)/chroot
	install -m 644 chroot/xbps.conf $(DESTDIR)$(SHAREDIR)/chroot
	if [ ! -d $(DESTDIR)$(ETCDIR) ]; then           \
		install -d $(DESTDIR)$(ETCDIR);         \
	fi
	if [ ! -f $(DESTDIR)$(ETCDIR)/$(CONF_FILE) ]; then      \
		install -m644 etc/$(CONF_FILE) $(DESTDIR)$(ETCDIR); \
	fi

.PHONY: uninstall
uninstall:
	-rm -f $(DESTDIR)$(SBINDIR)/xbps-src
	-rm -f $(DESTDIR)$(LIBEXECDIR)/xbps-src-doinst-helper
	-rm -rf $(DESTDIR)$(SHAREDIR)/shutils
	-rm -rf $(DESTDIR)$(SHAREDIR)/helpers
	-rm -rf $(DESTDIR)$(SHAREDIR)/chroot

dist:
	@echo "Building distribution tarball for tag: v$(VERSION) ..."
	-@git archive --format=tar --prefix=xbps-src-$(VERSION)/ \
		v$(VERSION) | gzip -9 > ~/xbps-src-$(VERSION).tar.gz

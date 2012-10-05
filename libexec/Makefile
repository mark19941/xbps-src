include ../vars.mk

SCRIPTS = xbps-src-doinst-helper

.PHONY: all
all:

.PHONY: clean
clean:

.PHONY: install
install:
	for bin in $(SCRIPTS); do					\
		install -Dm755 $$bin $(DESTDIR)$(LIBEXECDIR)/$$bin;	\
	done

.PHONY: uninstall
uninstall:
	for bin in $(SCRIPTS); do			\
		rm -f $(DESTDIR)$(LIBEXECDIR)/$$bin;	\
	done

## xbps-src - The XBPS binary package build system

xbps-src allow users to build XBPS binary packages in self-contained directories
(aka masterdirs).

Features:

 - Supports building debug packages
 - Supports cross compilation for multiple targets
 - A self-contained directory as master directory, multiple of them can be used.
 - Linux namespaces features (IPC/PID/mount) for masterdir

## Installation

Simply use the `make && make install clean` sequence to build and install it
into /usr/local by default. Some variables can be overriden thru make(1)
variables:

 - DESTDIR: empty
 - PREFIX: /usr/local by default
 - SBINDIR: PREFIX/sbin by default
 - SHAREDIR: PREFIX/share by default
 - LIBEXECDIR: PREFIX/libexec by default
 - ETCDIR: PREFIX/etc/xbps by default

By default the `PRIVILEGED_GROUP` is set to `xbuilder` but you can just set
it to your preferred group, remember that `xbps-src` must be installed as root
to set appropiate permissions to the `chroot helper`.

## Dependencies

- GNU bash
- fakeroot
- git
- xbps >= 0.33

The following packages are required to build a full bootstrap from scratch:

- GNU Awk
- GNU Binutils
- GNU Bison/Flex
- GNU CC with C++ support
- GNU Gettext (msgfmt)
- GNU patch
- GNU Tar
- gzip
- bzip2
- xz
- perl

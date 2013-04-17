#!/bin/bash
#
# Passed arguments:
#	$1 - pkgname to configure [REQUIRED]
#	$2 - cross target [OPTIONAL]

if [ $# -lt 1 -o $# -gt 2 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname [cross-target]"
	exit 1
fi

PKGNAME="$1"
XBPS_CROSS_BUILD="$2"

. $XBPS_CONFIG_FILE
. $XBPS_SHUTILSDIR/common.sh

for f in $XBPS_COMMONDIR/*.sh; do
	. $f
done

setup_pkg "$PKGNAME" $XBPS_CROSS_BUILD

if [ -z $pkgname -o -z $version ]; then
	msg_error "$1: pkgname or version not set in pkg template!\n"
fi

XBPS_CONFIGURE_DONE="$wrksrc/.xbps_${XBPS_CROSS_BUILD}_configure_done"
XBPS_PRECONFIGURE_DONE="$wrksrc/.xbps_${XBPS_CROSS_BUILD}_pre_configure_done"
XBPS_POSTCONFIGURE_DONE="$wrksrc/.xbps_${XBPS_CROSS_BUILD}_post_configure_done"

if [ -f "$XBPS_CONFIGURE_DONE" ]; then
	exit 0
fi

# Skip this phase for meta-template style builds.
if [ -n "$build_style" -a "$build_style" = "meta-template" ]; then
	exit 0
fi

cd $wrksrc || msg_error "$pkgver: cannot access wrksrc directory [$wrksrc].\n"
if [ -n "$build_wrksrc" ]; then
	cd $build_wrksrc || \
		msg_error "$pkgver: cannot access build_wrksrc directory [$build_wrksrc].\n"
fi

CONFIGURE_SHARED_ARGS="--prefix=/usr --sysconfdir=/etc --infodir=/usr/share/info --mandir=/usr/share/man --localstatedir=/var"

if [ "$XBPS_CROSS_BUILD" ]; then
	XBPS_PKGCONFIG_ARGS="
		PKG_CONFIG_SYSROOT_DIR=$XBPS_CROSS_BASE
		PKG_CONFIG_PATH=$XBPS_CROSS_BASE/lib/pkgconfig:$XBPS_CROSS_BASE/usr/share/pkgconfig
		PKG_CONFIG_LIBDIR=$XBPS_CROSS_BASE/lib/pkgconfig"

	CONFIGURE_SHARED_ARGS="${CONFIGURE_SHARED_ARGS}
		--host=$XBPS_CROSS_TRIPLET
		--with-sysroot=$XBPS_CROSS_BASE
		--with-libtool-sysroot=$XBPS_CROSS_BASE
		$XBPS_PKGCONFIG_ARGS"
fi

# Run pre_configure()
if [ ! -f $XBPS_PRECONFIGURE_DONE ]; then
	cd $wrksrc
	if [ -n "$build_wrksrc" ]; then
		cd $build_wrksrc
	fi
	if declare -f pre_configure >/dev/null; then
		run_func pre_configure
		touch -f $XBPS_PRECONFIGURE_DONE
	fi
fi

# Run do_configure()
cd $wrksrc
if [ -n "$build_wrksrc" ]; then
	cd $build_wrksrc
fi
if declare -f do_configure >/dev/null; then
	run_func do_configure
else
	if [ -n "$build_style" ]; then
		if [ ! -r $XBPS_HELPERSDIR/${build_style}.sh ]; then
			msg_error "$pkgver: cannot find build helper $XBPS_HELPERSDIR/${build_style}.sh!\n"
		fi
		. $XBPS_HELPERSDIR/${build_style}.sh
		if declare -f do_configure >/dev/null; then
			run_func do_configure
		fi
	fi
fi

touch -f $XBPS_CONFIGURE_DONE

# Run post_configure()
if [ ! -f $XBPS_POSTCONFIGURE_DONE ]; then
	cd $wrksrc
	if [ -n "$build_wrksrc" ]; then
		cd $build_wrksrc
	fi
	if declare -f post_configure >/dev/null; then
		run_func post_configure
		touch -f $XBPS_POSTCONFIGURE_DONE
	fi
fi

exit 0

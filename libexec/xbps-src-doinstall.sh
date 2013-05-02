#!//bin/bash
#
# Passed arguments:
#	$1 - pkgname [REQUIRED]
#	$2 - cross target [OPTIONAL]

if [ $# -lt 1 -o $# -gt 2 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname [cross-target]"
	exit 1
fi

PKGNAME="$1"
XBPS_CROSS_BUILD="$2"

. $XBPS_SHUTILSDIR/common.sh
. $XBPS_SHUTILSDIR/install_files.sh

for f in $XBPS_COMMONDIR/*.sh; do
	. $f
done

setup_pkg "$PKGNAME" $XBPS_CROSS_BUILD

if [ -z "$pkgname" -o -z "$version" ]; then
	msg_error "$1: pkgname/version not set in pkg template!\n"
fi

XBPS_INSTALL_DONE="$wrksrc/.xbps_${pkgname}_${XBPS_CROSS_BUILD}_install_done"
XBPS_PRE_INSTALL_DONE="$wrksrc/.xbps_${pkgname}_${XBPS_CROSS_BUILD}_pre_install_done"
XBPS_POST_INSTALL_DONE="$wrksrc/.xbps_${pkgname}_${XBPS_CROSS_BUILD}_post_install_done"

if [ -f $XBPS_INSTALL_DONE ]; then
	exit 0
fi
#
# There's nothing we can do if it is a meta template.
# Just creating the dir is enough.
#
if [ "$build_style" = "meta-template" ]; then
	mkdir -p $XBPS_DESTDIR/$pkgname-$version
	exit 0
fi

cd $wrksrc || msg_error "$pkgver: cannot access to wrksrc [$wrksrc]\n"
if [ -n "$build_wrksrc" ]; then
	cd $build_wrksrc \
		|| msg_error "$pkgver: cannot access to build_wrksrc [$build_wrksrc]\n"
fi

# Run pre_install()
if [ ! -f $XBPS_PRE_INSTALL_DONE ]; then
	if declare -f pre_install >/dev/null; then
		run_func pre_install
		touch -f $XBPS_PRE_INSTALL_DONE
	fi
fi

# Run do_install()
cd $wrksrc
[ -n "$build_wrksrc" ] && cd $build_wrksrc
if declare -f do_install >/dev/null; then
	run_func do_install
else
	if [ ! -r $XBPS_HELPERSDIR/${build_style}.sh ]; then
		msg_error "$pkgver: cannot find build helper $XBPS_HELPERSDIR/${build_style}.sh!\n"
	fi
	. $XBPS_HELPERSDIR/${build_style}.sh
	run_func do_install
fi

# Run post_install()
if [ ! -f $XBPS_POST_INSTALL_DONE ]; then
	cd $wrksrc
	[ -n "$build_wrksrc" ] && cd $build_wrksrc
	if declare -f post_install >/dev/null; then
		run_func post_install
		touch -f $XBPS_POST_INSTALL_DONE
	fi
fi

# Remove libtool archives by default.
if [ -z "$keep_libtool_archives" ]; then
	msg_normal "$pkgver: removing libtool archives...\n"
	find ${DESTDIR} -type f -name \*.la -delete
fi

# Remove bytecode python generated files.
msg_normal "$pkgver: removing python bytecode archives...\n"
find ${DESTDIR} -type f -name \*.py[co] -delete

# Always remove perllocal.pod and .packlist files.
if [ "$pkgname" != "perl" ]; then
	find ${DESTDIR} -type f -name perllocal.pod -delete
	find ${DESTDIR} -type f -name .packlist -delete
fi

# Remove empty directories by default.
for f in $(find ${DESTDIR} -depth -type d); do
	rmdir $f 2>/dev/null && \
		msg_warn "$pkgver: removed empty dir: ${f##${DESTDIR}}\n"
done

touch -f $XBPS_INSTALL_DONE

exit 0

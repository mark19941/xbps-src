#
# This helper is for templates using GNU configure script.
#

do_configure() {
	local args

	if [ -n "$XBPS_CROSS_TRIPLET" ]; then
		_args="--host=${XBPS_CROSS_TRIPLET}"
		_args="${_args} --with-libtool-sysroot=/usr/$XBPS_CROSS_TRIPLET"
		_args="${_args} PKG_CONFIG_SYSROOT_DIR=/usr/$XBPS_CROSS_TRIPLET"
		_args="${_args} PKG_CONFIG_LIBDIR=/usr/$XBPS_CROSS_TRIPLET/lib/pkgconfig"
	fi

	if [ -z "$configure_script" ]; then
		configure_script="./configure"
	fi
	# Make sure that shared libraries are built with --as-needed.
	#
	# http://lists.gnu.org/archive/html/libtool-patches/2004-06/msg00002.html
	if [ -z "$broken_as_needed" ]; then
		sed -i "s/^\([ \t]*tmp_sharedflag\)='-shared'/\1='-shared -Wl,--as-needed'/" ${configure_script}
	fi
	${configure_script} ${CONFIGURE_SHARED_ARGS} \
		${configure_args} ${_args}
}

# GNU configure scripts use make(1) to build/install.
. $XBPS_HELPERSDIR/gnu-makefile.sh

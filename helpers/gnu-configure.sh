#
# This helper is for templates using GNU configure script.
#

do_configure() {
	if [ -z "$configure_script" ]; then
		configure_script="./configure"
	fi
	# Make sure that shared libraries are built with --as-needed.
	#
	# http://lists.gnu.org/archive/html/libtool-patches/2004-06/msg00002.html
	if [ -z "$broken_as_needed" ]; then
		sed -i "s/^\([ \t]*tmp_sharedflag\)='-shared'/\1='-shared -Wl,--as-needed'/" ${configure_script}
	fi
	# Automatically detect musl toolchains.
	for f in $(find ${wrksrc} -type f -name *config*.sub); do
		cp -f ${XBPS_CROSSPFDIR}/config.sub ${f}
	done
	${configure_script} ${configure_args}
}

# GNU configure scripts use make(1) to build/install.
. $XBPS_HELPERSDIR/gnu-makefile.sh

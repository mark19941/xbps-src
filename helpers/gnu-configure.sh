#
# This helper is for templates using GNU configure script.
#

# This variable can be used for packages wanting to use common arguments
# to GNU configure scripts.
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
	${configure_script} ${CONFIGURE_SHARED_ARGS} ${configure_args}
}

# GNU configure scripts use make(1) to build/install.
. $XBPS_HELPERSDIR/gnu-makefile.sh

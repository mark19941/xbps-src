#
# This helper is for templates using cmake.
#
do_configure() {
	cmake -DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_SKIP_RPATH=ON \
		${configure_args} .
}

# cmake scripts use make(1) to build/install.
. $XBPS_HELPERSDIR/gnu-makefile.sh

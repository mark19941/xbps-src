#
# This helper is for templates installing python modules.
#
XBPS_PYVER="2.7" # currently 2.7 is the default python

do_build() {
	if [ -n "$XBPS_CROSS_TRIPLET" ]; then
		CC="${XBPS_CROSS_TRIPLET}-gcc -pthread"
		LDSHARED="${CC} -shared"
		CROSSBASE="/usr/$XBPS_CROSS_TRIPLET"
		PYPREFIX="$CROSSBASE"
		CFLAGS="$CFLAGS -I${CROSSBASE}/include/python${XBPS_PYVER} -I${CROSSBASE}/usr/include"
		LDFLAGS="$LDFLAGS -L${CROSSBASE}/lib/python${XBPS_PYVER} -L${CROSSBASE}/lib"
		env CC="$CC" LDSHARED="$LDSHARED" \
			PYPREFIX="$PYPREFIX" CFLAGS="$CFLAGS" \
			LDFLAGS="$LDFLAGS" python setup.py build ${make_build_args}
	else
		python setup.py build ${make_build_args}
	fi
}

do_install() {
	if [ -z "$make_install_args" ]; then
		make_install_args="--prefix=/usr --root=$DESTDIR"
	fi
	if [ -n "$XBPS_CROSS_TRIPLET" ]; then
		CC="${XBPS_CROSS_TRIPLET}-gcc -pthread"
		LDSHARED="${CC} -shared"
		CROSSBASE="/usr/$XBPS_CROSS_TRIPLET"
		PYPREFIX="$CROSSBASE"
		CFLAGS="$CFLAGS -I${CROSSBASE}/include/python${XBPS_PYVER} -I${CROSSBASE}/usr/include"
		LDFLAGS="$LDFLAGS -L${CROSSBASE}/lib/python${XBPS_PYVER} -L${CROSSBASE}/lib"
		env CC="$CC" LDSHARED="$LDSHARED" \
			PYPREFIX="$PYPREFIX" CFLAGS="$CFLAGS" \
			LDFLAGS="$LDFLAGS" python setup.py install ${make_install_args}
	else
		python setup.py install ${make_install_args}
	fi
}

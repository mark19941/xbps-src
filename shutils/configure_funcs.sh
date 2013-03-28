# -*-* shell *-*-
#
# Runs the "configure" phase for a pkg. This setups the Makefiles or any
# other stuff required to be able to build binaries or such.
#
export CONFIGURE_SHARED_ARGS="--prefix=/usr --sysconfdir=/etc
	--infodir=/usr/share/info --mandir=/usr/share/man
	--localstatedir=/var"

configure_src_phase() {
	local f= rval=

	[ -z $pkgname ] && return 1
	[ -f "$XBPS_CONFIGURE_DONE" ] && return 0

	# Skip this phase for meta-template style builds.
	[ -n "$build_style" -a "$build_style" = "meta-template" ] && return 0

	cd $wrksrc || msg_error "$pkgver: cannot access wrksrc directory [$wrksrc].\n"
	if [ -n "$build_wrksrc" ]; then
		cd $build_wrksrc || \
			msg_error "$pkgver: cannot access build_wrksrc directory [$build_wrksrc].\n"
	fi

	if [ -n "$XBPS_CROSS_BUILD" ]; then
		XBPS_PKGCONFIG_ARGS="
			PKG_CONFIG_SYSROOT_DIR=$XBPS_CROSS_BASE
			PKG_CONFIG_LIBDIR=$XBPS_CROSS_BASE/lib/pkgconfig"

		CONFIGURE_SHARED_ARGS="${CONFIGURE_SHARED_ARGS}
			--host=$XBPS_CROSS_TRIPLET
			--with-sysroot=$XBPS_CROSS_BASE
			--with-libtool-sysroot=$XBPS_CROSS_BASE
			$XBPS_PKGCONFIG_ARGS"
	fi

	# Run pre_configure func.
	if [ ! -f $XBPS_PRECONFIGURE_DONE ]; then
		cd $wrksrc
		[ -n "$build_wrksrc" ] && cd $build_wrksrc
		if declare -f pre_configure >/dev/null; then
			run_func pre_configure
			touch -f $XBPS_PRECONFIGURE_DONE
		fi
	fi


	if [ -r $XBPS_HELPERSDIR/${build_style}.sh ]; then
		. $XBPS_HELPERSDIR/${build_style}.sh
	fi
	# run do_configure()
	cd $wrksrc
	[ -n "$build_wrksrc" ] && cd $build_wrksrc
	if declare -f do_configure >/dev/null; then
		run_func do_configure
		touch -f $XBPS_CONFIGURE_DONE
	fi

	# Run post_configure func.
	if [ ! -f $XBPS_POSTCONFIGURE_DONE ]; then
		cd $wrksrc
		[ -n "$build_wrksrc" ] && cd $build_wrksrc
		if declare -f post_configure >/dev/null; then
			run_func post_configure
			touch -f $XBPS_POSTCONFIGURE_DONE
		fi
	fi
}

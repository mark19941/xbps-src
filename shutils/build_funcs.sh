# -*-* shell *-*-
#
# Runs the "build" phase for a pkg. This builds the binaries and other
# related stuff.
#
build_src_phase() {
	local rval=

	[ -z $pkgname -o -z $version ] && return 1
	[ -f "$XBPS_BUILD_DONE" ] && return 0

	# Skip this phase for meta-template style builds.
	[ -n "$build_style" -a "$build_style" = "meta-template" ] && return 0

	cd $wrksrc || msg_error "$pkgver: cannot access wrksrc directory [$wrksrc]\n"
	if [ -n "$build_wrksrc" ]; then
		cd $build_wrksrc || \
			msg_error "$pkgver: cannot access build_wrksrc directory [$build_wrksrc]\n"
	fi

	. $XBPS_SHUTILSDIR/common_funcs.sh

	# Run pre_build func.
	if [ ! -f $XBPS_PRE_BUILD_DONE ]; then
		cd $wrksrc
		[ -n "$build_wrksrc" ] && cd $build_wrksrc
		if declare -f pre_build >/dev/null; then
			run_func pre_build
			touch -f $XBPS_PRE_BUILD_DONE
		fi
	fi

	if [ -r $XBPS_HELPERSDIR/${build_style}.sh ]; then
		. $XBPS_HELPERSDIR/${build_style}.sh
	fi

	# do_build()
	cd $wrksrc
	[ -n "$build_wrksrc" ] && cd $build_wrksrc
	if declare -f do_build >/dev/null; then
		run_func do_build
		touch -f $XBPS_BUILD_DONE
	fi
	# Run post_build func.
	if [ ! -f $XBPS_POST_BUILD_DONE ]; then
		cd $wrksrc
		[ -n "$build_wrksrc" ] && cd $build_wrksrc
		if declare -f post_build >/dev/null; then
			run_func post_build
			touch -f $XBPS_POST_BUILD_DONE
		fi
	fi
}

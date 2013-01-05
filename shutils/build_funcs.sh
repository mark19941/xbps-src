# -*-* shell *-*-
#
# Runs the "build" phase for a pkg. This builds the binaries and other
# related stuff.
#
build_src_phase() {
	local rval=

	[ -z $pkgname -o -z $version ] && return 1

	# Skip this phase for meta-template style builds.
	[ -n "$build_style" -a "$build_style" = "meta-template" ] && return 0

	cd $wrksrc || msg_error "$pkgver: cannot access wrksrc directory [$wrksrc]\n"
	if [ -n "$build_wrksrc" ]; then
		cd $build_wrksrc || \
			msg_error "$pkgver: cannot access build_wrksrc directory [$build_wrksrc]\n"
	fi

	if [ -n "$XBPS_MAKEJOBS" -a -z "$disable_parallel_build" ]; then
		makejobs="-j$XBPS_MAKEJOBS"
	fi

	# Run pre_build func.
	if [ ! -f $XBPS_PRE_BUILD_DONE ]; then
		cd $wrksrc
		[ -n "$build_wrksrc" ] && cd $build_wrksrc
		run_func pre_build
		[ $? -eq 0 ] && touch -f $XBPS_PRE_BUILD_DONE
	fi

	if [ -r $XBPS_HELPERSDIR/${build_style}.sh ]; then
		. $XBPS_HELPERSDIR/${build_style}.sh
	fi

	# do_build()
	cd $wrksrc
	[ -n "$build_wrksrc" ] && cd $build_wrksrc
	run_func do_build
	rval=$?

	# Run post_build func.
	if [ ! -f $XBPS_POST_BUILD_DONE ]; then
		cd $wrksrc
		[ -n "$build_wrksrc" ] && cd $build_wrksrc
		run_func post_build
		[ $? -eq 0 ] && touch -f $XBPS_POST_BUILD_DONE
	fi

	[ "$rval" -eq 0 ] && touch -f $XBPS_BUILD_DONE
	return 0
}

# -*-* shell *-*-

show_build_options() {
	[ -z "$PKG_BUILD_OPTIONS" ] && return 0

	msg_normal "$pkgver: build options: "
	for f in ${PKG_BUILD_OPTIONS}; do
		printf "$f "
	done
	msg_normal_append "\n"
}

check_pkg_arch() {
	if [ -n "$BEGIN_INSTALL" -a -n "$only_for_archs" ]; then
		if [ -n "$XBPS_CROSS_BUILD" ]; then
			if $(echo "$only_for_archs"|grep -q "$XBPS_TARGET_MACHINE"); then
				found=1
			fi
		else
			if $(echo "$only_for_archs"|grep -q "$XBPS_MACHINE"); then
				found=1
			fi
		fi
		if [ -z "$found" ]; then
			msg_red "$pkgname: this package cannot be built on $XBPS_MACHINE.\n"
			exit 0
		fi
	fi
}

install_pkg() {
	local target="$1" lrepo=

	[ -z "$pkgname" ] && return 1

	show_build_options
	check_pkg_arch

	# Install dependencies required by this package.
	install_pkg_deps || return 1
	if [ -n "$TARGETPKG_PKGDEPS_DONE" ]; then
		unset TARGETPKG_PKGDEPS_DONE
		remove_pkg_autodeps
		setup_pkg $XBPS_TARGET_PKG
	fi

	# Fetch distfiles after installing required dependencies,
	# because some of them might be required for do_fetch().
	$XBPS_LIBEXECDIR/xbps-src-dofetch $sourcepkg || exit 1
	[ "$target" = "fetch" ] && return 0

	# Fetch, extract, build and install into the destination directory.
	$XBPS_LIBEXECDIR/xbps-src-doextract $sourcepkg || exit 1
	[ "$target" = "extract" ] && return 0

	# Apply patches if requested by template file
	$XBPS_LIBEXECDIR/xbps-src-dopatch $sourcepkg || exit 1

	# Run configure phase
	$XBPS_LIBEXECDIR/xbps-src-doconfigure $sourcepkg $XBPS_CROSS_BUILD || exit 1
	[ "$target" = "configure" ] && return 0

	# Run build phase
	$XBPS_LIBEXECDIR/xbps-src-dobuild $sourcepkg $XBPS_CROSS_BUILD || exit 1
	[ "$target" = "build" ] && return 0

	# Install pkg into destdir.
	$FAKEROOT_CMD $XBPS_LIBEXECDIR/xbps-src-doinstall $sourcepkg || exit 1

	# Install subpkgs into destdir.
	for subpkg in ${subpackages}; do
		if [ ! -r $XBPS_SRCPKGDIR/$subpkg/${subpkg}.template ]; then
			msg_error "$pkgver: cannot read ${subpkg}.template!\n"
		fi
		. $XBPS_SRCPKGDIR/$subpkg/${subpkg}.template

		$FAKEROOT_CMD $XBPS_LIBEXECDIR/xbps-src-doinstall $subpkg || exit 1

		# Strip binaries/libraries.
		$XBPS_LIBEXECDIR/xbps-src-dostrip $subpkg $XBPS_CROSS_BUILD || exit 1

		# Generate run-time dependecies.
		$XBPS_LIBEXECDIR/xbps-src-genrdeps $subpkg || exit 1

		# Generate binpkg.
		$XBPS_LIBEXECDIR/xbps-src-genpkg $subpkg || exit 1
	done

	# Strip binaries/libraries.
	$XBPS_LIBEXECDIR/xbps-src-dostrip $sourcepkg $XBPS_CROSS_BUILD || exit 1

	# Generate run-time dependecies.
	$XBPS_LIBEXECDIR/xbps-src-genrdeps $sourcepkg || exit 1

	# Generate binpkg.
	$XBPS_LIBEXECDIR/xbps-src-genpkg $sourcepkg || exit 1

	# Remove pkg and its subpkgs from destdir.
	remove_pkg $sourcepkg

	# pkg cleanup
	if declare -f do_clean >/dev/null; then
		run_func do_clean
	fi

	# Remove autodeps if current pkg is the target pkg.
	if [ "$sourcepkg" = "$XBPS_TARGET_PKG" ]; then
		if [ -z "$XBPS_KEEP_ALL" ]; then
			remove_pkg_autodeps
			remove_pkg_wrksrc
		fi
		if [ -n "$CHROOT_READY" ]; then
			exit 0
		fi
	else
		remove_pkg_autodeps
		remove_pkg_wrksrc
	fi

	# If base-chroot not installed, install binpkg into masterdir
	# from local repository.
	if [ -z "$CHROOT_READY" ]; then
		msg_normal "Installing $pkgver into masterdir...\n"
		local _log=$(mktemp --tmpdir|| exit 1)
		$FAKEROOT_CMD $XBPS_INSTALL_CMD -y $pkgver >${_log} 2>&1
		if [ $? -ne 0 ]; then
			msg_red "Failed to install $pkgver into masterdir, see below for errors:\n"
			cat ${_log}
			rm -f ${_log}
			msg_error "Cannot continue!"
		fi
		rm -f ${_log}
	fi
}

remove_pkg_wrksrc() {
	if [ -d "$wrksrc" ]; then
		msg_normal "$pkgver: cleaning build directory...\n"
		rm -rf $wrksrc
	fi
}

remove_pkg() {
	local subpkg= pkg= _destdir=

	[ -z $pkgname ] && msg_error "unexistent package, aborting.\n"

	if [ -n "$XBPS_CROSS_BUILD" ]; then
		_destdir="$XBPS_DESTDIR/$XBPS_CROSS_TRIPLET"
	else
		_destdir="$XBPS_DESTDIR"
	fi

	for subpkg in ${subpackages}; do
		. ${XBPS_SRCPKGDIR}/${sourcepkg}/${subpkg}.template
		set_pkg_common_vars
		pkg="${subpkg}-${version}"
		if [ -n "$revision" ]; then
			local _pkg="${pkg}_${revision}"
		fi
		if [ -d "${_destdir}/${pkg}" ]; then
			msg_normal "${_pkg}: removing files from destdir...\n"
			rm -rf "${_destdir}/${pkg}"
		else
			msg_warn "${_pkg}: not installed in destdir!\n"
		fi
		for f in install pre_install post_install strip; do
			rm -f $wrksrc/.xbps_${subpkg}_${XBPS_CROSS_BUILD}_${f}_done
		done
		# Remove -dbg packages.
		if [ -d "${_destdir}/${subpkg}-dbg-${version}" ]; then
			msg_normal "${_pkg}: removing debug pkg...\n"
			rm -rf ${_destdir}/${subpkg}-dbg-${version}
		fi
	done

	pkg="${pkgname}-${version}"
	if [ -d "${_destdir}/${pkg}" ]; then
		msg_normal "${pkgver}: removing files from destdir...\n"
		rm -rf "${_destdir}/${pkg}"
	fi
	# Remove -dbg pkg.
	if [ -d "${_destdir}/${pkgname}-dbg-${version}" ]; then
		msg_normal "${pkgver}: removing debug pkg...\n"
		rm -rf ${_destdir}/${pkgname}-dbg-${version}
	fi

	for f in install pre_install post_install strip; do
		rm -f $wrksrc/.xbps_${sourcepkg}_${XBPS_CROSS_BUILD}_${f}_done
	done
}

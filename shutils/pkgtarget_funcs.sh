# -*-* shell *-*-

set_build_options() {
	local f j opt optval _optsset
	local -A options

	[ ! -f $XBPS_SRCPKGDIR/$pkgname/template.options ] && return 0

	. $XBPS_SRCPKGDIR/$pkgname/template.options

	for f in ${build_options}; do
		OIFS="$IFS"; IFS=','
		for j in ${XBPS_BUILD_OPTS}; do
			opt=${j#\~}
			opt_disabled=${j:0:1}
			if [ "$opt" = "$f" ]; then
				if [ "$opt_disabled" != "~" ]; then
					options[$opt]=1
				else
					options[$opt]=0
				fi
			fi
		done
		IFS="$OIFS"
	done

	for f in ${build_options_default}; do
		optval=${options[$f]}
		if [[ -z "$optval" ]] || [[ $optval -eq 1 ]]; then
			options[$f]=1
		fi
	done

	# Prepare final options.
	for f in ${!options[@]}; do
		optval=${options[$f]}
		[[ $optval -eq 1 ]] && eval build_option_${f}=1
	done

	if declare -f do_options >/dev/null; then
		do_options
	fi

	for f in ${build_options}; do
		optval=${options[$f]}
		if [[ $optval -eq 1 ]]; then
			state=enabled
			_optsset="${_optsset} ${f}"
		else
			state=disabled
			_optsset="${_optsset} ~${f}"
		fi
	done

	for f in ${_optsset}; do
		if [ -z "$PKG_BUILD_OPTIONS" ]; then
			PKG_BUILD_OPTIONS="$f"
		else
			PKG_BUILD_OPTIONS="$PKG_BUILD_OPTIONS $f"
		fi
	done
}

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
	if [ ! -f "$XBPS_INSTALL_DONE" ]; then
		install_pkg_deps || return 1
		if [ -n "$ORIGIN_PKGDEPS_DONE" ]; then
			unset ORIGIN_PKGDEPS_DONE
			setup_tmpl ${_ORIGINPKG}
		fi
	fi

	# Fetch distfiles after installing required dependencies,
	# because some of them might be required for do_fetch().
	fetch_distfiles

	# Fetch, extract, build and install into the destination directory.
	extract_distfiles

	# Apply patches if requested by template file
	apply_tmpl_patches

	# Run configure phase
	configure_src_phase
	[ "$target" = "configure" ] && return 0

	# Run build phase
	build_src_phase
	[ "$target" = "build" ] && return 0

	# Install pkg into destdir.
	if [ ! -f "$XBPS_INSTALL_DONE" ]; then
		env XBPS_MACHINE=${XBPS_MACHINE} 			\
			XBPS_TARGET_MACHINE=${XBPS_TARGET_MACHINE}	\
			XBPS_CROSS_BUILD=${XBPS_CROSS_BUILD}		\
			wrksrc=${wrksrc} MASTERDIR="${XBPS_MASTERDIR}"	\
			CONFIG_FILE=${XBPS_CONFIG_FILE}			\
			XBPS_SRC_VERSION="${XBPS_SRC_VERSION}"		\
			${FAKEROOT_CMD} ${XBPS_LIBEXECDIR}/xbps-src-doinst-helper	\
			${sourcepkg} || exit 1

		# Strip binaries/libraries.
		strip_files

		# Write metadata to package's destdir.
		write_metadata
	fi

	cd $XBPS_MASTERDIR
	# If install-destdir specified, we are done.
	if [ "$target" = "install-destdir" ]; then
		if [ "$pkgname" = "${_ORIGINPKG}" ]; then
			exit 0
		fi
	fi
	# Build binpkg and remove files from destdir.
	make_binpkg
	rval=$?
	[ $rval -ne 0 -a $rval -ne 6 ] && return $rval
	remove_pkg

	# Remove $wrksrc if -C not specified.
	if [ -d "$wrksrc" -a -z "$KEEP_WRKSRC" ]; then
		remove_tmpl_wrksrc $wrksrc
	fi

	# pkg cleanup
	if declare -f do_clean >/dev/null; then
		run_func do_clean
	fi

	# Remove autodeps if target pkg is the origin pkg.
	if [ "$pkgname" = "${_ORIGINPKG}" ]; then
		[ -z "$KEEP_AUTODEPS" ] && remove_pkg_autodeps
		[ -n "$CHROOT_READY" ] && exit 0
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

remove_pkg() {
	local subpkg= pkg= target="$1"

	[ -z $pkgname ] && msg_error "unexistent package, aborting.\n"

	if [ -n "$XBPS_CROSS_BUILD" ]; then
		_destdir="$XBPS_DESTDIR/$XBPS_CROSS_TRIPLET"
	else
		_destdir="$XBPS_DESTDIR"
	fi

	for subpkg in ${subpackages}; do
		. ${XBPS_SRCPKGDIR}/${sourcepkg}/${subpkg}.template
		set_tmpl_common_vars
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
		# Remove leftover files in $wrksrc.
		if [ -f "${wrksrc}/.xbps_${XBPS_CROSS_TRIPLET}_do_install_${subpkg}_done" ]; then
			rm -f ${wrksrc}/.xbps_${XBPS_CROSS_TRIPLET}_do_install_${subpkg}_done
		fi
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

	[ -f $XBPS_PRE_INSTALL_DONE ] && rm -f $XBPS_PRE_INSTALL_DONE
	[ -f $XBPS_POST_INSTALL_DONE ] && rm -f $XBPS_POST_INSTALL_DONE
	[ -f $XBPS_INSTALL_DONE ] && rm -f $XBPS_INSTALL_DONE
}

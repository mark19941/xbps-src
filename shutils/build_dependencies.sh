# -*-* shell *-*-
#
# Install a required package dependency, like:
#
#	xbps-install -Ay <pkgname>
#
# Returns 0 if package already installed or installed successfully.
# Any other error number otherwise.
#
install_pkg_from_repos() {
	local pkg="$1" cross="$2" rval= tmplogf=

	tmplogf=$(mktemp)
	if [ -n "$cross" ]; then
		$FAKEROOT_CMD $XBPS_INSTALL_XCMD -Ayd "$pkg" >$tmplogf 2>&1
	else
		$FAKEROOT_CMD $XBPS_INSTALL_CMD -Ayd "$pkg" >$tmplogf 2>&1
	fi
	rval=$?
	if [ $rval -ne 0 -a $rval -ne 17 ]; then
		# xbps-install can return:
		#
		#	SUCCESS  (0): package installed successfully.
		#	ENOENT   (2): package missing in repositories.
		#	EEXIST  (17): package already installed.
		#	ENODEV  (19): package depends on missing dependencies.
		#	ENOTSUP (95): no repositories registered.
		#
		[ -z "$XBPS_KEEP_ALL" ] && remove_pkg_autodeps
		msg_red "$pkgver: failed to install '$1' dependency! (error $rval)\n"
		cat $tmplogf && rm -f $tmplogf
		msg_error "Please see above for the real error, exiting...\n"
	fi
	rm -f $tmplogf
	[ $rval -eq 17 ] && rval=0
	return $rval
}

#
# Installs all dependencies required by a package.
#
install_pkg_deps() {
	local pkg="$1" cross="$2" curpkgdepname pkgn iver _props _exact

	local -a binpkg_deps
	local -a missing_deps

	[ -z "$pkgname" ] && return 2

	setup_pkg_depends

	if [ -z "$build_depends" -a -z "$host_build_depends" ]; then
		return 0
	fi

	msg_normal "$pkgver: required dependencies:\n"
	#
	# Native build dependencies.
	#
	for i in ${host_build_depends}; do
		pkgn=$($XBPS_UHELPER_CMD getpkgdepname "${i}")
		if [ -z "$pkgn" ]; then
			pkgn=$($XBPS_UHELPER_CMD getpkgname "${i}")
			if [ -z "$pkgn" ]; then
				msg_error "$pkgver: invalid build dependency: ${i}\n"
			fi
			_exact=1
		fi
		check_pkgdep_matched "${i}"
		local rval=$?
		if [ $rval -eq 0 ]; then
			iver=$($XBPS_UHELPER_CMD version "${pkgn}")
			if [ $? -eq 0 -a -n "$iver" ]; then
				echo "   ${i}: found '$pkgn-$iver'."
				continue
			fi
		elif [ $rval -eq 1 ]; then
			iver=$($XBPS_UHELPER_CMD version "${pkgn}")
			if [ $? -eq 0 -a -n "$iver" ]; then
				echo "   ${i}: installed ${iver} (unresolved) removing..."
				$FAKEROOT_CMD $XBPS_REMOVE_CMD -iyf $pkgn >/dev/null 2>&1
			fi
		else
			if [ -n "${_exact}" ]; then
				unset _exact
				_props=$($XBPS_QUERY_CMD -R -ppkgver,repository "${pkgn}" 2>/dev/null)
			else
				_props=$($XBPS_QUERY_CMD -R -ppkgver,repository "${i}" 2>/dev/null)
			fi
			if [ -n "${_props}" ]; then
				set -- ${_props}
				$XBPS_UHELPER_CMD pkgmatch ${1} "${i}"
				if [ $? -eq 1 ]; then
					echo "   ${i}: found $1 in $2."
					binpkg_deps+=("$1")
					shift 2
					continue
				else
					echo "   ${i}: not found."
				fi
				shift 2
			else
				echo "   ${i}: not found."
			fi
		fi
		missing_deps+=("$i")
	done

	for i in ${missing_deps[@]}; do
		# packages not found in repos, install from source.
		curpkgdepname=$($XBPS_UHELPER_CMD getpkgdepname "$i")
		setup_subpkg $curpkgdepname
		# Check if version in srcpkg satisfied required dependency,
		# and bail out if doesn't.
		${XBPS_UHELPER_CMD} pkgmatch "$pkgver" "$i"
		if [ $? -eq 0 ]; then
			setup_subpkg $XBPS_TARGET_PKG
			msg_error_nochroot "$pkgver: required dependency '$i' cannot be resolved!\n"
		fi
		install_pkg full
		setup_pkg $XBPS_TARGET_PKG
		install_pkg_deps $sourcepkg
	done
	if [ "$TARGETPKG_PKGDEPS_DONE" ]; then
		return 0
	fi
	for i in ${binpkg_deps[@]}; do
		msg_normal "$pkgver: installing '$i' (native)...\n"
		install_pkg_from_repos "${i}"
	done

	unset binpkg_deps missing_deps
	local -a binpkg_deps
	local -a missing_deps

	#
	# Cross or library build dependencies.
	#
	for i in ${build_depends}; do
		pkgn=$($XBPS_UHELPER_CMD getpkgdepname "${i}")
		if [ -z "$pkgn" ]; then
			pkgn=$($XBPS_UHELPER_CMD getpkgname "${i}")
			if [ -z "$pkgn" ]; then
				msg_error "$pkgver: invalid build dependency: ${i}\n"
			fi
			_exact=1
		fi
		check_pkgdep_matched "${i}" $cross
		local rval=$?
		if [ $rval -eq 0 ]; then
			iver=$($XBPS_UHELPER_XCMD version "${pkgn}")
			if [ $? -eq 0 -a -n "$iver" ]; then
				echo "   ${i}: found '$pkgn-$iver'."
				continue
			fi
		elif [ $rval -eq 1 ]; then
			iver=$($XBPS_UHELPER_XCMD version "${pkgn}")
			if [ $? -eq 0 -a -n "$iver" ]; then
				echo "   ${i}: installed ${iver} (unresolved) removing..."
				$XBPS_REMOVE_XCMD -iyf $pkgn >/dev/null 2>&1
			fi
		else
			if [ -n "${_exact}" ]; then
				unset _exact
				_props=$($XBPS_QUERY_XCMD -R -ppkgver,repository "${pkgn}" 2>/dev/null)
			else
				_props=$($XBPS_QUERY_XCMD -R -ppkgver,repository "${i}" 2>/dev/null)
			fi
			if [ -n "${_props}" ]; then
				set -- ${_props}
				$XBPS_UHELPER_CMD pkgmatch ${1} "${i}"
				if [ $? -eq 1 ]; then
					echo "   ${i}: found $1 in $2."
					binpkg_deps+=("$1")
					shift 2
					continue
				else
					echo "   ${i}: not found."
				fi
				shift 2
			else
				echo "   ${i}: not found."
			fi
		fi
		missing_deps+=("$i")
	done

	for i in ${missing_deps[@]}; do
		# packages not found in repos, install from source.
		curpkgdepname=$($XBPS_UHELPER_CMD getpkgdepname "$i")
		setup_subpkg $curpkgdepname $cross
		# Check if version in srcpkg satisfied required dependency,
		# and bail out if doesn't.
		$XBPS_UHELPER_CMD pkgmatch "$pkgver" "$i"
		if [ $? -eq 0 ]; then
			setup_subpkg $XBPS_TARGET_PKG $cross
			msg_error_nochroot "$pkgver: required dependency '$i' cannot be resolved!\n"
		fi
		install_pkg full $cross
		setup_pkg $XBPS_TARGET_PKG $cross
		install_pkg_deps $sourcepkg $cross
	done
	if [ "$TARGETPKG_PKGDEPS_DONE" ]; then
		return 0
	fi
	for i in ${binpkg_deps[@]}; do
		msg_normal "$pkgver: installing '$i' ...\n"
		install_pkg_from_repos "$i" $cross
	done
	if [ "$XBPS_TARGET_PKG" = "$sourcepkg" ]; then
		TARGETPKG_PKGDEPS_DONE=1
	fi
}

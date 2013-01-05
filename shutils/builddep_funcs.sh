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
	local rval= tmplogf=

	tmplogf=$(mktemp)
	$FAKEROOT_CMD $XBPS_INSTALL_CMD -Ay "$1" >$tmplogf 2>&1
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
		remove_pkg_autodeps $KEEP_AUTODEPS
		msg_red "$pkgver: failed to install '$1' dependency! (error $rval)\n"
		cat $tmplogf && rm -f $tmplogf
		msg_error "Please see above for the real error, exiting...\n"
	fi
	rm -f $tmplogf
	[ $rval -eq 17 ] && rval=0
	return $rval
}

remove_pkg_autodeps() {
	local rval= tmplogf=

	[ -n "$1" -o -z "$CHROOT_READY" ] && return 0

	cd $XBPS_MASTERDIR || return 1
	msg_normal "$pkgver: removing automatic pkgdeps, please wait...\n"
	# Autoremove installed binary packages.
	tmplogf=$(mktemp)
	$FAKEROOT_CMD $XBPS_RECONFIGURE_CMD -a && \
		$FAKEROOT_CMD $XBPS_REMOVE_CMD -Ryo >$tmplogf 2>&1
	if [ $? -ne 0 ]; then
		msg_red "$pkgver: failed to remove automatic dependencies:\n"
		cat $tmplogf && rm -f $tmplogf
		msg_error "$pkgver: cannot continue!\n"
	fi
	rm -f $tmplogf
}

#
# Installs all dependencies required by a package.
#
install_pkg_deps() {
	local i= pkgn= iver= missing_deps= binpkg_deps= _props= _subpkg= _exact=

	[ -z "$pkgname" ] && return 2
	[ -z "$build_depends" ] && return 0
	[ -n "$ORIGIN_PKGDEPS_DONE" ] && return 0

	# Remove autodeps in case a dependency was built from source.
	for i in ${subpackages}; do
		if [ "${i}" = "${pkgname}" ]; then
			_subpkg=1
			break
		fi
	done

	if [ "$pkgname" != "${_ORIGINPKG}" -a -z "${_subpkg}" -a -n "$CHROOT_READY" ]; then
		remove_pkg_autodeps || return $?
	fi
	unset _subpkg

	msg_normal "$pkgver: required dependencies:\n"

	#
	# Packages built in masterdir.
	#
	for i in ${build_depends}; do
		pkgn=$($XBPS_UHELPER_CMD getpkgdepname "${i}")
		if [ -z "$pkgn" ]; then
			pkgn=$($XBPS_UHELPER_CMD getpkgname "${i}")
			if [ -z "$pkgn" ]; then
				msg_error "$pkgver: invalid build dependency: $i\n"
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
				_props=$($XBPS_QUERY_CMD -R -pversion,repository "${pkgn}" 2>/dev/null)
			else
				_props=$($XBPS_QUERY_CMD -R -pversion,repository "${i}" 2>/dev/null)
			fi
			if [ -n "${_props}" ]; then
				set -- ${_props}
				$XBPS_UHELPER_CMD pkgmatch ${pkgn}-${1} "${i}"
				if [ $? -eq 1 ]; then
					echo "   ${i}: found $1 in $2."
					if [ -z "$binpkg_deps" ]; then
						binpkg_deps="${pkgn}-${1}"
					else
						binpkg_deps="${binpkg_deps} ${pkgn}-${1}"
					fi
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
		if [ -z "$missing_deps" ]; then
			missing_deps="${i}"
		else
			missing_deps="${missing_deps} ${i}"
		fi
	done
	for i in ${missing_deps}; do
		# packages not found in repos, install from source.
		curpkgdepname=$($XBPS_UHELPER_CMD getpkgdepname "$i")
		setup_tmpl ${curpkgdepname}
		# Check if version in srcpkg satisfied required dependency,
		# and bail out if doesn't.
		${XBPS_UHELPER_CMD} pkgmatch "$pkgver" "$i"
		if [ $? -eq 0 ]; then
			setup_tmpl ${_ORIGINPKG}
			msg_error_nochroot "$pkgver: required dependency '$i' cannot be resolved!\n"
		fi
		install_pkg
		setup_tmpl ${_ORIGINPKG}
		cd ${XBPS_MASTERDIR}
		install_pkg_deps
	done
	for i in ${binpkg_deps}; do
		msg_normal "$pkgver: installing '$i'...\n"
		install_pkg_from_repos "${i}"
	done
	if [ "$pkgname" = "${_ORIGINPKG}" ]; then
		ORIGIN_PKGDEPS_DONE=1
		return 0
	fi
}

#
# Returns 0 if pkgpattern in $1 is matched against current installed
# package, 1 if no match and 2 if not installed.
#
check_pkgdep_matched() {
	local pkg="$1" pkgn= iver=

	[ -z "$pkg" ] && return 255

	pkgn="$($XBPS_UHELPER_CMD getpkgdepname ${pkg})"
	if [ -z "$pkgn" ]; then
		pkgn="$($XBPS_UHELPER_CMD getpkgname ${pkg})"
	fi
	[ -z "$pkgn" ] && return 255

	iver="$($XBPS_UHELPER_CMD version $pkgn)"
	if [ $? -eq 0 -a -n "$iver" ]; then
		${XBPS_UHELPER_CMD} pkgmatch "${pkgn}-${iver}" "${pkg}"
		[ $? -eq 1 ] && return 0
	else
		return 2
	fi

	return 1
}

#
# Returns 0 if pkgpattern in $1 is installed and greater than current
# installed package, otherwise 1.
#
check_installed_pkg() {
	local pkg="$1" pkgn= iver=

	[ -z "$pkg" ] && return 2

	pkgn="$($XBPS_UHELPER_CMD getpkgname ${pkg})"
	[ -z "$pkgn" ] && return 2

	iver="$($XBPS_UHELPER_CMD version $pkgn)"
	if [ $? -eq 0 -a -n "$iver" ]; then
		${XBPS_CMPVER_CMD} "${pkgn}-${iver}" "${pkg}"
		[ $? -eq 0 -o $? -eq 1 ] && return 0
	fi

	return 1
}

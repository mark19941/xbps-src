#-
# Copyright (c) 2008-2012 Juan Romero Pardines.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#-

#
# Install a required package dependency, like:
#
#	xbps-bin -Ay install <pkgname>
#
# Returns 0 if package already installed or installed successfully.
# Any other error number otherwise.
#
install_pkg_from_repos() {
	local rval= tmplogf=

	_pkgdepname=$($XBPS_PKGDB_CMD getpkgname "$1")
	tmplogf=$(mktemp)
	$FAKEROOT_CMD $XBPS_BIN_CMD -Ay install ${_pkgdepname} >$tmplogf 2>&1
	rval=$?
	if [ $rval -ne 0 -a $rval -ne 17 ]; then
		# xbps-bin can return:
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

	[ -n "$1" ] && return 0

	cd $XBPS_MASTERDIR || return 1
	msg_normal "$pkgver: removing automatic pkgdeps, please wait...\n"
	# Autoremove installed binary packages.
	tmplogf=$(mktemp)
	$FAKEROOT_CMD $XBPS_BIN_CMD reconfigure all && \
		${FAKEROOT_CMD} ${XBPS_BIN_CMD} -Ry autoremove >$tmplogf 2>&1
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
	local i= pkgn= iver= missing_deps= binpkg_deps=

	[ -z "$pkgname" ] && return 2
	[ -z "$build_depends" ] && return 0
	[ -n "$ORIGIN_PKGDEPS_DONE" ] && return 0

	if [ "$pkgname" != "${_ORIGINPKG}" ]; then
		remove_pkg_autodeps || return $?
	fi
	msg_normal "$pkgver: required dependencies:\n"

	if [ -n "$IN_CHROOT" ]; then
		#
		# Packages built in masterdir.
		#
		for i in ${build_depends}; do
			pkgn=$($XBPS_PKGDB_CMD getpkgdepname "${i}")
			check_pkgdep_matched "${i}"
			local rval=$?
			if [ $rval -eq 0 ]; then
				iver=$($XBPS_BIN_CMD show -oversion "${pkgn}")
				if [ $? -eq 0 -a -n "$iver" ]; then
					echo "   ${i}: found '$pkgn-$iver'."
					continue
				fi
			elif [ $rval -eq 1 ]; then
				iver=$($XBPS_BIN_CMD show -oversion "${pkgn}")
				if [ $? -eq 0 -a -n "$iver" ]; then
					echo "   ${i}: installed ${iver} (unresolved) removing..."
					$FAKEROOT_CMD $XBPS_BIN_CMD -yFf remove $pkgn >/dev/null 2>&1
				fi
			else
				repover=$($XBPS_REPO_CMD -oversion show $pkgn 2>/dev/null)
				if [ $? -eq 0 ]; then
					$XBPS_PKGDB_CMD pkgmatch ${pkgn}-${repover} "${i}"
					if [ $? -eq 1 ]; then
						repoloc=$($XBPS_REPO_CMD -orepository show $pkgn)
						echo "   ${i}: found $repover in $repoloc."
						if [ -z "$binpkg_deps" ]; then
							binpkg_deps="${pkgn}-${repover}"
						else
							binpkg_deps="${binpkg_deps} ${pkgn}-${repover}"
						fi
						continue
					else
						echo "   ${i}: not found."
					fi
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
			curpkgdepname=$($XBPS_PKGDB_CMD getpkgdepname "$i")
			setup_tmpl ${curpkgdepname}
			install_pkg
			setup_tmpl ${_ORIGINPKG}
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
	else
		#
		# Packages built in host directories.
		#
		for i in ${build_depends}; do
			pkgn=$($XBPS_PKGDB_CMD getpkgdepname "${i}")
			iver=$($XBPS_PKGDB_CMD version "${pkgn}")
			check_pkgdep_matched "${i}"
			local rval=$?
			if [ $rval -eq 0 ]; then
				echo "   ${i}: found '$pkgn-$iver'."
				continue
			elif [ $rval -eq 1 ]; then
				echo "   ${i}: installed ${iver} (unresolved) removing $iver..."
				setup_tmpl $pkgn
				remove_pkg
				setup_tmpl ${_ORIGINPKG}
				install_pkg_deps
			else
				echo "   ${i} not found."
			fi
			if [ -z "$missing_deps" ]; then
				missing_deps="${i}"
			else
				missing_deps="${missing_deps} ${i}"
			fi
		done
		# Install required dependencies from source.
		for i in ${missing_deps}; do
			curpkgdepname=$($XBPS_PKGDB_CMD getpkgdepname "$i")
			setup_tmpl ${curpkgdepname}
			install_pkg
			setup_tmpl ${_ORIGINPKG}
			install_pkg_deps
		done
		if [ "$pkgname" = "${_ORIGINPKG}" ]; then
			ORIGIN_PKGDEPS_DONE=1
			return 0
		fi
	fi
}

#
# Returns 0 if pkgpattern in $1 is matched against current installed
# package, 1 if no match and 2 if not installed.
#
check_pkgdep_matched() {
	local pkg="$1" pkgn= iver=

	[ -z "$pkg" ] && return 255

	pkgn="$($XBPS_PKGDB_CMD getpkgdepname ${pkg})"
	[ -z "$pkgn" ] && return 255

	iver="$($XBPS_BIN_CMD show -oversion $pkgn)"
	if [ $? -ne 0 -o -z "$iver" ]; then
		iver="$($XBPS_PKGDB_CMD version $pkgn)"
	fi

	if [ $? -eq 0 -a -n "$iver" ]; then
		${XBPS_PKGDB_CMD} pkgmatch "${pkgn}-${iver}" "${pkg}"
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

	pkgn="$($XBPS_PKGDB_CMD getpkgname ${pkg})"
	[ -z "$pkgn" ] && return 2

	iver="$($XBPS_BIN_CMD show -oversion $pkgn)"
	if [ $? -ne 0 -o -z "$iver" ]; then
		iver="$($XBPS_PKGDB_CMD version $pkgn)"
	fi
	if [ $? -eq 0 -a -n "$iver" ]; then
		${XBPS_CMPVER_CMD} "${pkgn}-${iver}" "${pkg}"
		[ $? -eq 0 -o $? -eq 1 ] && return 0
	fi

	return 1
}

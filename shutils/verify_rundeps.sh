# -*-* shell *-*-
#
# Finds all required shlibs for a package, by looking at its
# executables/shlibs and skipping duplicated matches.

add_rundep() {
	local dep="$1" i= rpkgdep= _depname= _rdeps= found=

	_depname="$($XBPS_UHELPER_CMD getpkgdepname ${dep} 2>/dev/null)"
	if [ -z "${_depname}" ]; then
		_depname="$($XBPS_UHELPER_CMD getpkgname ${dep} 2>/dev/null)"
	fi

	for i in ${run_depends}; do
		rpkgdep="$($XBPS_UHELPER_CMD getpkgdepname $i 2>/dev/null)"
		if [ -z "$rpkgdep" ]; then
			rpkgdep="$($XBPS_UHELPER_CMD getpkgname $i 2>/dev/null)"
		fi
		if [ "${rpkgdep}" != "${_depname}" ]; then
			continue
		fi
		$XBPS_UHELPER_CMD cmpver "$i" "$dep"
		rval=$?
		if [ $rval -eq 255 ]; then
			_rdeps="$(echo ${run_depends}|sed -e "s|${i}|${dep}|g")"
			run_depends="${_rdeps}"
		fi
		found=1
	done
	if [ -z "$found" ]; then
		run_depends="${run_depends} ${dep}"
	fi
}

verify_rundeps() {
	local j= f= nlib= verify_deps= maplib= found_dup= igndir=
	local broken= rdep= found= tmplf=
	local _pkgname= _rdepver= _subpkg= _sdep=

	maplib=$XBPS_COMMONDIR/shlibs

	[ -n "$noarch" -o -n "$noverifyrdeps" ] && return 0
	msg_normal "$pkgver: verifying required shlibs...\n"

	depsftmp=$(mktemp -t xbps_src_depstmp.XXXXXXXXXX) || exit 1
	find ${1} -type f -perm -u+w > $depsftmp 2>/dev/null

	exec 3<&0 # save stdin
	exec < $depsftmp
	while read f; do
		# Don't check dirs specified in ignore_vdeps_dir.
		for j in ${ignore_vdeps_dir}; do
			if grep -q ${j} "${f}"; then
				igndir=1
				break
			fi
		done
		[ -n "$igndir" ] && continue
		unset igndir

		case "$(file -bi "$f")" in
		application/x-executable*|application/x-sharedlib*)
			for nlib in $(objdump -p "$f"|grep NEEDED|awk '{print $2}'); do
				if [ -z "$verify_deps" ]; then
					verify_deps="$nlib"
					continue
				fi
				for j in ${verify_deps}; do
					[ "$j" != "$nlib" ] && continue
					found_dup=1
					break
				done
				if [ -z "$found_dup" ]; then
					verify_deps="$verify_deps $nlib"
				fi
				unset found_dup
			done
			;;
		esac
	done
	exec 0<&3 # restore stdin
	rm -f $depsftmp

	if [ -f $XBPS_SRCPKGDIR/$pkgname/$pkgname.template ]; then
		tmplf=$XBPS_SRCPKGDIR/$pkgname/$pkgname.template
	else
		tmplf=$XBPS_SRCPKGDIR/$pkgname/template
	fi
	#
	# Add required run time packages by using required shlibs resolved
	# above, the mapping is done thru the mapping_shlib_binpkg.txt file.
	#
	for f in ${verify_deps}; do
		unset _f j rdep _rdep rdepcnt soname _pkgname _rdepver found
		local _f=$(echo "$f"|sed 's|\+|\\+|g')
		rdep="$(grep -E "^${_f}[[:blank:]]+.*$" $maplib|awk '{print $2}')"
		rdepcnt="$(grep -E "^${_f}[[:blank:]]+.*$" $maplib|awk '{print $2}'|wc -l)"
		if [ -z "$rdep" ]; then
			# Ignore libs by current pkg
			soname=$(find ${DESTDIR} -name "$f")
			if [ -z "$soname" ]; then
				msg_red_nochroot "   SONAME: $f <-> UNKNOWN PKG PLEASE FIX!\n"
				broken=1
			else
				echo "   SONAME: $f <-> $pkgname (ignored)"
			fi
			continue
		elif [ "$rdepcnt" -gt 1 ]; then
			unset j found
			# Check if shlib is provided by multiple pkgs.
			for j in ${rdep}; do
				_pkgname=$($XBPS_UHELPER_CMD getpkgname "$j")
				# if there's a SONAME matching pkgname, use it.
				[ "${pkgname}" != "${_pkgname}" ] && continue
				found=1
				break
			done
			if [ -n "$found" ]; then
				_rdep=$j
			else
				# otherwise pick up the first one.
				for j in ${rdep}; do
					[ -z "${_rdep}" ] && _rdep=$j
				done
			fi
		else
			_rdep=$rdep
		fi
		_pkgname=$($XBPS_UHELPER_CMD getpkgname "${_rdep}" 2>/dev/null)
		_rdepver=$($XBPS_UHELPER_CMD getpkgversion "${_rdep}" 2>/dev/null)
		if [ -z "${_pkgname}" -o -z "${_rdepver}" ]; then
			msg_red_nochroot "   SONAME: $f <-> UNKNOWN PKG PLEASE FIX!\n"
			broken=1
			continue
		fi
		# Check if pkg is a subpkg of sourcepkg; if true, ignore version
		# in common/shlibs.
		_sdep="${_pkgname}>=${_rdepver}"
		for _subpkg in ${subpackages}; do
			if [ "${_subpkg}" = "${_pkgname}" ]; then
				_sdep="${_pkgname}-${version}_${revision}"
				break
			fi
		done

		if [ "${_pkgname}" != "${pkgname}" ]; then
			echo "   SONAME: $f <-> ${_sdep}"
		else
			# Ignore libs by current pkg
			echo "   SONAME: $f <-> ${_rdep} (ignored)"
			continue
		fi
		add_rundep "${_sdep}"
	done
	#
	# If pkg uses any unknown SONAME error out.
	#
	if [ -n "$broken" ]; then
		msg_error "$pkgver: cannot guess required shlibs, aborting!\n"
	fi
}

#-
# Copyright (c) 2010-2012 Juan Romero Pardines.
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
# Finds all required libraries for a package, by looking at its executables
# and shared libraries and skipping duplicated matches.
#
# Once the list is known it finds the binary package names mapped to those
# libraries and reports if any of them was not added.
#

find_rundep() {
	local dep="$1" i= rpkgdep= _depname=

	_depname="$($XBPS_PKGDB_CMD getpkgdepname ${dep})"

	for i in ${run_depends}; do
		rpkgdep="$($XBPS_PKGDB_CMD getpkgdepname $i)"
		[ "${rpkgdep}" != "${_depname}" ] && continue
		$XBPS_PKGDB_CMD cmpver "$i" "$dep"
		if [ $? -eq 255 ]; then
			run_depends=$(echo ${run_depends}|sed -e "s|${i}||g")
		fi
		return 1
	done
}

verify_rundeps() {
	local j= f= nlib= verify_deps= maplib= found_dup= igndir= soname_arch=
	local broken= rdep= found= rsonamef= soname_list= tmplf=
	local _pkgname= _rdepver=

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
		unset j rdep _rdep rdepcnt soname _pkgname _rdepver
		rdep="$(grep "^${f}.*$" $maplib|awk '{print $2}')"
		rdepcnt="$(grep "^${f}.*$" $maplib|awk '{print $2}'|wc -l)"
		if [ -z "$rdep" ]; then
			# Ignore libs by current pkg
			soname=$(find ${DESTDIR} -name "$f")
			if [ -z "$soname" ]; then
				echo "   SONAME: $f <-> UNKNOWN PKG PLEASE FIX!"
				broken=1
			else
				echo "   SONAME: $f <-> $pkgname (ignored)"
			fi
			continue
		elif [ "$rdepcnt" -gt 1 ]; then
			unset j found
			# Check if shlib is provided by multiple pkgs.
			for j in ${rdep}; do
				_pkgname=$($XBPS_PKGDB_CMD getpkgname "$j")
				# if there's a SONAME matching pkgname, use it.
				[ "${j}" != "${_pkgname}" ] && continue
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
		_pkgname=$($XBPS_PKGDB_CMD getpkgname "${_rdep}" 2>/dev/null)
		_rdepver=$($XBPS_PKGDB_CMD getpkgversion "${_rdep}" 2>/dev/null)
		if [ -z "${_pkgname}" -o -z "${_rdepver}" ]; then
			echo "   SONAME: $f <-> UNKNOWN PKG PLEASE FIX!"
			broken=1
			continue
		fi
		if [ "${_pkgname}" != "${pkgname}" ]; then
			echo "   SONAME: $f <-> ${_pkgname}>=${_rdepver}"
		else
			# Ignore libs by current pkg
			echo "   SONAME: $f <-> ${_rdep} (ignored)"
			continue
		fi
		# Add required shlib to rundeps.
		if [ -z "$soname_list" ]; then
			soname_list="${f}"
		else
			soname_list="${soname_list} ${f}"
		fi
		if find_rundep "${_pkgname}>=${_rdepver}"; then
			run_depends="${run_depends} ${_pkgname}>=${_rdepver}"
		fi
	done
	#
	# If pkg uses any SONAME not known, error out.
	#
	[ -n "$broken" ] && \
		msg_error "$pkgver: cannot guess required shlibs, aborting!\n"

	#
	# Update package's rshlibs file.
	#
	unset broken f
	msg_normal "$pkgver: updating rshlibs file...\n"
	rsonamef=${XBPS_SRCPKGDIR}/${pkgname}/${pkgname}.rshlibs
	if [ ! -f $rsonamef ]; then
		# file not found, add soname.
		for j in ${soname_list}; do
			echo "   SONAME: $j (added)"
			echo "${j}" >> $rsonamef
		done
		[ -n "$soname_list" ] && broken=1
	else
		# check if soname is already in the rshlibs file.
		for j in ${soname_list}; do
			if ! grep -q "$j" $rsonamef; then
				echo "   SONAME: $j (added)"
				echo "$j" >> $rsonamef
				broken=1
			fi
		done
		unset f
		exec 3<&0 # save stdin
		exec < $rsonamef
		# now check if any soname in the rshlibs file is unnecessary.
		while read f; do
			local _soname=$(echo "$f"|awk '{print $1}')
			local _soname_arch=$(echo "$f"|awk '{print $2}')

			for j in ${soname_list}; do
				if [ "${_soname}" = "$j" ]; then
					found=1
					continue
				fi
			done
			if [ -n "$found" ]; then
				unset found
				continue
			fi
			# Sometimes a required SONAME is arch dependent, so
			# ignore it in such case.
			if [ -n "${_soname_arch}" -a "${_soname_arch}" != "$XBPS_MACHINE" ]; then
				continue
			fi

			# If SONAME is arch specific, only remove it if
			# matching on the target arch.
			_soname_arch=$(grep "$f" $maplib|awk '{print $3}')
			if [ -z "${_soname_arch}" ] || \
			   [ -n "${_soname_arch}" -a "${_soname_arch}" = "$XBPS_MACHINE" ]; then
				echo "   SONAME: $f (removed, not required)"
				sed -i "/^${_soname}$/d" $rsonamef
				broken=1
			fi
			unset _soname _soname_arch
		done
		exec 0<&3 # restore stdin
	fi

	[ -z "$broken" ] && return 0

	# ERROR shlibs unmatched.
	msg_red "$pkgver: required run-time shared libraries do not match!\n"
	msg_red "  Please check why required shared libraries were modified and bump\n"
	msg_red "  revision number if necessary in package's template file.\n"
	msg_red "  Possible reasons:\n"
	msg_red "   - A package was detected in configure that added new features.\n"
	msg_red "   - A package wasn't detected in configure that removed some features.\n"
	msg_red "   - A required package that was used in previous build is not being used.\n"
	msg_red "   - A required package bumped the major version of any of its SONAMEs.\n"
	msg_red "  If you don't know what to do please contact the package maintainer.\n"

	export BROKEN_RSHLIBS=1
}

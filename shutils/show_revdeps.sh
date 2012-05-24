#-
# Copyright (c) 2011-2012 Juan Romero Pardines.
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

_show_hard_pkg_deps() {
	local f= deps= tmplf= revdepname=

	deps=$(grep -El "^(fulldepends|depends)=\".*${1}.*\"" $XBPS_SRCPKGDIR/*/*template)
	for f in ${deps}; do
		unset tmplf revdepname j curpkgn found
		[ -h "$(dirname $f)" ] && continue
		tmplf=$(basename "$f")
		if [ "$tmplf" != template ]; then
			revdepname=${tmplf%.template}
		else
			revdepname=$(basename $(dirname "$f"))
		fi
		setup_subpkg_tmpl $revdepname
		for j in ${run_depends}; do
			curpkgn=$($XBPS_PKGDB_CMD getpkgdepname "$j")
			[ "$curpkgn" != "$1" ] && continue
			found=1 && break
		done
		if [ -n "$found" ]; then
			unset found
			if [ -z "$REVDEPS" ]; then
				REVDEPS="$revdepname"
			else
				for j in ${REVDEPS}; do
					[ "$j" != "$revdepname" ] && continue
					found=1 && break
				done
				if [ -z "$found" ]; then
					REVDEPS="$REVDEPS $revdepname"
				fi
			fi
		fi
	done
}

_show_shlib_pkg_deps() {
	local f= j= soname=

	soname=$(echo "$1"|sed 's|\+|\\+|g')

	revshlibs=$(grep -E "^${soname}.*$" ${XBPS_SRCPKGDIR}/*/*.rshlibs)
	for f in ${revshlibs}; do
		unset pkg revdepname tmprev
		revdepname=$(basename "$f")
		revdepname=${revdepname%.rshlibs*}
		tmprev=$(echo "$revdepname"|sed 's/-//g')
		eval pkg=\$pkg_"${tmprev}"
		if [ -z "${pkg}" ]; then
			eval local pkg_${tmprev}=1
			if [ -z "$REVDEPS" ]; then
				REVDEPS="$revdepname"
			else
				for j in ${REVDEPS}; do
					[ "$j" != "$revdepname" ] && continue
					found=1 && break
				done
				if [ -z "$found" ]; then
					REVDEPS="$REVDEPS $revdepname"
				fi
			fi
		fi
	done
}

show_pkg_revdeps() {
	local SHLIBS_MAP=$XBPS_COMMONDIR/shlibs
	local _pkgn= shlibs=

	[ -z "$1" ] && return 1

	_pkgn=$(echo "$1"|sed 's|\+|\\+|g')

	shlibs=$(grep -E "^lib.*\.so\.[[:digit:]]+[[:blank:]]+${_pkgn}\-.*[[:blank:]]?.*$" $SHLIBS_MAP|awk '{print $1}')
	if [ -n "$shlibs" ]; then
		# pkg provides shlibs
		_show_shlib_pkg_deps "$shlibs"
	fi
	# show pkgs that use Add_dependency
	_show_hard_pkg_deps "${_pkgn}"

	echo $REVDEPS
	unset REVDEPS
}

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

git_revs() {
	local _revs= _out= f= _filerev= _files=

	# Get the git revisions from this source pkg.
	cd $XBPS_SRCPKGDIR
	_files=$(git ls-files $1)
	[ -z "${_files}" ] && return

	for f in ${_files}; do
		_filerev=$(git rev-list HEAD $f | head -n1)
		[ -z "${_filerev}" ] && continue
		_out="${f} ${_filerev}"
		if [ -z "${_revs}" ]; then
			_revs="${_out}"
		else
			_revs="${_revs} ${_out}"
		fi
	done

	SRCPKG_GITREVS_FILE=$(mktemp --tmpdir || msg_error "$pkgver: failed to create tmpfile.\n")
	echo "$pkgver git source revisions:"
	set -- ${_revs}
	while [ $# -gt 0 ]; do
		local _branch=$1; _file=$2; local _rev=$3
		echo "${_file}: ${_rev}"
		echo "${_file}: ${_rev}" >> ${SRCPKG_GITREVS_FILE}
		shift 3
	done
}

make_binpkg() {
	local subpkg= rval=

	[ -z "$pkgname" ] && return 1

	msg_normal "$pkgver: fetching source git revisions, please wait...\n"
	git_revs $pkgname

	for subpkg in ${subpackages}; do
		unset nonfree conf_files noarch triggers replaces softreplace \
			system_accounts system_groups preserve \
			xml_entries sgml_entries xml_catalogs sgml_catalogs \
			font_dirs dkms_modules provides kernel_hooks_version \
			conflicts pycompile_dirs pycompile_module \
			systemd_services make_dirs \
			depends fulldepends run_depends mutable_files
		. $XBPS_SRCPKGDIR/$pkgname/$subpkg.template
		pkgname=${subpkg}
		set_tmpl_common_vars
		make_binpkg_real
		setup_tmpl ${sourcepkg}
	done

	if [ -n "${subpackages}" ]; then
		setup_tmpl ${sourcepkg}
	fi
	make_binpkg_real
	rval=$?

	rm -f ${SRCPKG_GITREVS_FILE}
	unset SRCPKG_GITREVS_FILE

	return $rval
}

binpkg_cleanup() {
	local pkgdir="$1" binpkg="$2"

	[ -z "$pkgdir" -o -z "$binpkg" ] && return 1
	msg_red "$pkgver: Interrupted! removing $binpkg file!\n"
	if [ -n "$nonfree" ]; then
		rm -f $XBPS_PACKAGESDIR/nonfree/$binpkg
	else
		rm -f $XBPS_PACKAGESDIR/$binpkg
	fi
	rm -f $pkgdir/$binpkg
	exit 1
}

#
# This function builds a binary package from an installed xbps
# package in destdir.
#
make_binpkg_real() {
	local binpkg= pkgdir= arch= _deps= f=

	if [ ! -d "${DESTDIR}" ]; then
		msg_warn "$pkgver: cannot find destdir... skipping!\n"
		return 0
	fi

	if [ -n "$noarch" ]; then
		arch=noarch
	else
		arch=$XBPS_MACHINE
	fi
	binpkg=$pkgver.$arch.xbps
	if [ -n "$nonfree" ]; then
		pkgdir=$XBPS_PACKAGESDIR/nonfree/$arch
	else
		pkgdir=$XBPS_PACKAGESDIR/$arch
	fi
	#
	# Don't overwrite existing binpkgs by default, skip them.
	#
	if [ -f $pkgdir/$binpkg ]; then
		msg_normal "$pkgver: skipping existing $binpkg pkg...\n"
		return 6 # EEXIST
	fi

	#
	# Start building the binary package...
	#
	trap "binpkg_cleanup $pkgdir $binpkg" INT
	msg_normal "Building $binpkg...\n"
	if [ ! -d $pkgdir ]; then
		mkdir -p $pkgdir
	fi
	cd $pkgdir

	[ -n "$preserve" ] && _preserve="-p"
	[ -s ${DESTDIR}/rdeps ] && _deps="$(cat ${DESTDIR}/rdeps)"
	if [ -n "$provides" ]; then
		local _provides=
		for f in ${provides}; do
			_provides="${_provides} ${f}"
		done
	fi
	if [ -n "$conflicts" ]; then
		local _conflicts=
		for f in ${conflicts}; do
			_conflicts="${_conflicts} ${f}"
		done
	fi
	if [ -n "$replaces" ]; then
		local _replaces=
		for f in ${replaces}; do
			_replaces="${_replaces} ${f}"
		done
	fi
	if [ -n "$mutable_files" ]; then
		local _mutable_files=
		for f in ${mutable_files}; do
			_mutable_files="${_mutable_files} ${f}"
		done
	fi
	if [ -n "$conf_files" ]; then
		local _conf_files=
		for f in ${conf_files}; do
			_conf_files="${_conf_files} ${f}"
		done
	fi

	#
	# Create the XBPS binary package.
	#
	${FAKEROOT_CMD} ${XBPS_CREATE_CMD} \
		--architecture ${arch} \
		--provides "${_provides}" \
		--conflicts "${_conflicts}" \
		--replaces "${_replaces}" \
		--mutable-files "${_mutable_files}" \
		--dependencies "${_deps}" \
		--config-files "${_conf_files}" \
		--homepage "${homepage}" \
		--license "${license}" \
		--maintainer "${maintainer}" \
		--long-desc "${long_desc}" --desc "${short_desc}" \
		--built-with "xbps-src-${XBPS_SRC_VERSION}" \
		--pkgver "${pkgver}" \
		--source-revisions "$(cat $SRCPKG_GITREVS_FILE 2>/dev/null)" \
		--quiet ${_preserve} ${DESTDIR}
	rval=$?
	trap - INT

	if [ $rval -eq 0 ]; then
		msg_normal "Built $binpkg successfully.\n"
		if [ -n "$nonfree" ]; then
			while [ -f $XBPS_PACKAGESDIR/nonfree/.xbps-src-index-lock ]; do
				echo "The repo index is currently locked!"
				sleep 1
			done
			ln -sfr $pkgdir/$binpkg $XBPS_PACKAGESDIR/nonfree/$binpkg
			touch -f $XBPS_PACKAGESDIR/nonfree/.xbps-src-index-lock
			$XBPS_RINDEX_CMD -a $XBPS_PACKAGESDIR/nonfree/$binpkg
			rm -f $XBPS_PACKAGESDIR/nonfree/.xbps-src-index-lock
		else
			while [ -f $XBPS_PACKAGESDIR/.xbps-src-index-lock ]; do
				echo "The repo index is currently locked!"
				sleep 1
			done
			ln -sfr $pkgdir/$binpkg $XBPS_PACKAGESDIR/$binpkg
			touch -f $XBPS_PACKAGESDIR/.xbps-src-index-lock
			$XBPS_RINDEX_CMD -a $XBPS_PACKAGESDIR/$binpkg
			rm -f $XBPS_PACKAGESDIR/.xbps-src-index-lock
		fi
	else
		if [ -n "$nonfree" ]; then
			rm -f $XBPS_PACKAGESDIR/nonfree/$binpkg
		else
			rm -f $XBPS_PACKAGESDIR/$binpkg
		fi
		rm -f $pkgdir/$binpkg
		msg_error "Failed to build binary package: $binpkg!\n"
	fi
}

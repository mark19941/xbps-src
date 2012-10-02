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

make_binpkg() {
	local subpkg= rval=

	[ -z "$pkgname" ] && return 1

	for subpkg in ${subpackages}; do
		unset nonfree conf_files noarch triggers replaces softreplace \
			system_accounts system_groups \
			preserve xml_entries sgml_entries \
			xml_catalogs sgml_catalogs gconf_entries gconf_schemas \
			gtk_iconcache_dirs font_dirs dkms_modules provides \
			kernel_hooks_version conflicts pycompile_dirs \
			pycompile_module systemd_services make_dirs \
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

	if [ -n "$nonfree" ]; then
		while [ -f $XBPS_PACKAGESDIR/nonfree/.xbps-src-index-lock ]; do
			echo "The repo index is currently locked!"
			sleep 1
		done
		touch -f $XBPS_PACKAGESDIR/nonfree/.xbps-src-index-lock
		$XBPS_REPO_CMD index-clean $XBPS_PACKAGESDIR/nonfree
		rm -f $XBPS_PACKAGESDIR/nonfree/.xbps-src-index-lock
	else
		while [ -f $XBPS_PACKAGESDIR/.xbps-src-index-lock ]; do
			echo "The repo index is currently locked!"
			sleep 1
		done
		touch -f $XBPS_PACKAGESDIR/.xbps-src-index-lock
		$XBPS_REPO_CMD index-clean $XBPS_PACKAGESDIR
		rm -f $XBPS_PACKAGESDIR/.xbps-src-index-lock
	fi

	return $?
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
	local binpkg= pkgdir= arch= _deps=

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

	[ -n "${preserve}" ] && _preserve="-p"
	[ -s ${DESTDIR}/rdeps ] && _deps="$(cat ${DESTDIR}/rdeps)"

	#
	# Create the XBPS binary package.
	#
	${FAKEROOT_CMD} ${XBPS_CREATE_CMD} \
		--architecture ${arch} \
		--provides "${provides}" \
		--conflicts "${conflicts}" \
		--replaces "${replaces}" \
		--mutable-files "${mutable_files}" \
		--dependencies "${_deps}" \
		--config-files "${conf_files}" \
		--homepage "${homepage}" \
		--license "${license}" \
		--maintainer "${maintainer}" \
		--long-desc "${long_desc}" --desc "${short_desc}" \
		--built-with "xbps-src-${XBPS_SRC_VERSION}" \
		--pkgver "${pkgver}" --quiet ${_preserve} \
		${DESTDIR}
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
			$XBPS_REPO_CMD index-add $XBPS_PACKAGESDIR/nonfree/$binpkg
			rm -f $XBPS_PACKAGESDIR/nonfree/.xbps-src-index-lock
		else
			while [ -f $XBPS_PACKAGESDIR/.xbps-src-index-lock ]; do
				echo "The repo index is currently locked!"
				sleep 1
			done
			ln -sfr $pkgdir/$binpkg $XBPS_PACKAGESDIR/$binpkg
			touch -f $XBPS_PACKAGESDIR/.xbps-src-index-lock
			$XBPS_REPO_CMD index-add $XBPS_PACKAGESDIR/$binpkg
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

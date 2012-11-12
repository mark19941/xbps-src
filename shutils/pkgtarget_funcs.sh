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
# Installs a pkg by reading its build template file.
#
install_pkg() {
	local target="$1" lrepo=

	[ -z "$pkgname" ] && return 1

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
	if [ ! -f "$XBPS_EXTRACT_DONE" ]; then
		extract_distfiles || return $?
	fi

	# Apply patches if requested by template file
	if [ ! -f $XBPS_APPLYPATCHES_DONE ]; then
		apply_tmpl_patches || return $?
	fi

	if [ ! -f "$XBPS_CONFIGURE_DONE" ]; then
		configure_src_phase || return $?
		[ "$target" = "configure" ] && return 0
	fi

	if [ ! -f "$XBPS_BUILD_DONE" ]; then
		build_src_phase || return $?
		[ "$target" = "build" ] && return 0
	fi

	# Install pkg into destdir.
	if [ ! -f "$XBPS_INSTALL_DONE" ]; then
		env XBPS_MACHINE=${XBPS_MACHINE} wrksrc=${wrksrc}	\
			MASTERDIR="${XBPS_MASTERDIR}"			\
			CONFIG_FILE=${XBPS_CONFIG_FILE}			\
			XBPS_SRC_VERSION=${XBPS_SRC_VERSION}		\
			${FAKEROOT_CMD} ${XBPS_LIBEXECDIR}/xbps-src-doinst-helper \
			${sourcepkg} || return $?

		# Strip binaries/libraries.
		strip_files

		# Write metadata to package's destdir.
		write_metadata
		if [ $? -ne 0 ]; then
			msg_red "$pkgver: failed to create package metadata!\n"
			remove_pkgdestdir_sighandler $pkgname
			return 1
		fi
	fi

	if [ -n "$BROKEN_RSHLIBS" ]; then
		unset BROKEN_RSHLIBS
		msg_error "$pkgver: can't continue because required shlibs do not match.\n"
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
	remove_pkg || return $?

	# Remove $wrksrc if -C not specified.
	if [ -d "$wrksrc" -a -z "$KEEP_WRKSRC" ]; then
		remove_tmpl_wrksrc $wrksrc
	fi

	# Remove autodeps if target pkg is the origin pkg.
	if [ "$pkgname" = "${_ORIGINPKG}" ]; then
		remove_pkg_autodeps $KEEP_AUTODEPS || return 1
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

#
# Removes package files from destdir.
#
remove_pkg() {
	local subpkg= pkg= target="$1"

	[ -z $pkgname ] && msg_error "unexistent package, aborting.\n"

	for subpkg in ${subpackages}; do
		. ${XBPS_SRCPKGDIR}/${sourcepkg}/${subpkg}.template
		set_tmpl_common_vars
		pkg="${subpkg}-${version}"
		if [ -n "$revision" ]; then
			local _pkg="${pkg}_${revision}"
		fi
		if [ -d "$XBPS_DESTDIR/${pkg}" ]; then
			msg_normal "${_pkg}: removing files from destdir...\n"
			rm -rf "$XBPS_DESTDIR/${pkg}"
		else
			msg_warn "${_pkg}: not installed in destdir!\n"
		fi
		# Remove leftover files in $wrksrc.
		if [ -f "${wrksrc}/.xbps_do_install_${subpkg}_done" ]; then
			rm -f ${wrksrc}/.xbps_do_install_${subpkg}_done
		fi
	done

	pkg="${pkgname}-${version}"
	if [ -d "$XBPS_DESTDIR/${pkg}" ]; then
		msg_normal "${pkgver}: removing files from destdir...\n"
		rm -rf "$XBPS_DESTDIR/${pkg}"
	fi

	[ -f $XBPS_PRE_INSTALL_DONE ] && rm -f $XBPS_PRE_INSTALL_DONE
	[ -f $XBPS_POST_INSTALL_DONE ] && rm -f $XBPS_POST_INSTALL_DONE
	[ -f $XBPS_INSTALL_DONE ] && rm -f $XBPS_INSTALL_DONE
}

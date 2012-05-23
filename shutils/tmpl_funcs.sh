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
# Resets all vars used by a template.
#
reset_tmpl_vars() {
	local TMPL_VARS="pkgname distfiles configure_args strip_cmd \
			make_build_args make_install_args build_style	\
			short_desc maintainer long_desc checksum wrksrc	\
			make_cmd bootstrap register_shell \
			make_build_target configure_script noextract nofetch \
			nostrip nonfree build_requires \
			make_install_target version revision patch_args \
			sgml_catalogs xml_catalogs xml_entries sgml_entries \
			disable_parallel_build font_dirs preserve \
			only_for_archs conf_files keep_libtool_archives \
			noarch subpackages sourcepkg gtk_iconcache_dirs \
			abi_depends api_depends triggers make_dirs \
			replaces system_accounts system_groups provides \
			build_wrksrc create_wrksrc broken_as_needed pkgver \
			ignore_vdeps_dir noverifyrdeps conflicts dkms_modules \
			gconf_entries gconf_schemas create_srcdir \
			pycompile_dirs pycompile_module systemd_services  \
			homepage license kernel_hooks_version makejobs \
			mutable_files nostrip_files skip_extraction \
			run_depends build_depends \
			depends makedepends fulldepends \
			SUBPKG XBPS_EXTRACT_DONE XBPS_CONFIGURE_DONE \
			XBPS_BUILD_DONE XBPS_INSTALL_DONE FILESDIR DESTDIR \
			SRCPKGDESTDIR PATCHESDIR CFLAGS CXXFLAGS CPPFLAGS \
			CC CXX LDFLAGS LD_LIBRARY_PATH"

	local TMPL_FUNCS="pre_configure pre_build pre_install do_build \
			  do_install do_configure post_configure post_build \
			  post_install do_fetch pre_remove post_remove \
			  post_stow post_extract"

	eval unset -v "$TMPL_VARS"
	eval unset -f "$TMPL_FUNCS"
}

#
# Reads a template file and setups required variables for operations.
#
setup_tmpl() {
	local pkg="$1"

	[ -z "$pkg" ] && return 1

	if [ "$pkgname" = "$pkg" ]; then
		[ -n "$DESTDIR" ] && return 0
	fi

	if [ -f $XBPS_SRCPKGDIR/${pkg}/template ]; then
		reset_tmpl_vars
		. $XBPS_SRCPKGDIR/${pkg}/template
		prepare_tmpl
	else
		msg_error "Cannot find $pkg build template file.\n"
	fi

}

setup_subpkg_tmpl() {
	local f=

	[ -z "$1" ] && return 1

	if [ -r "$XBPS_SRCPKGDIR/$1/$1.template" ]; then
		setup_tmpl $1
		unset build_depends depends run_depends
		. $XBPS_SRCPKGDIR/$1/$1.template
		for f in ${subpackages}; do
			[ "$f" != "$1" ] && continue
			pkgname=$f
			SUBPKG=1
			set_tmpl_common_vars
			break
		done
	else
		setup_tmpl $1
	fi
}

#
# Checks some vars used in templates and sets some of them required.
#
prepare_tmpl() {
	local REQ_VARS= i= found=

	REQ_VARS="pkgname version short_desc long_desc"

	if [ -n "$build_style" -a "$build_style" = "meta-template" ]; then
		nofetch=yes
		noextract=yes
	fi

	# Check if required vars weren't set.
	for i in ${REQ_VARS}; do
		eval val="\$$i"
		if [ -z "$val" -o -z "$i" ]; then
			msg_error "\"$i\" not set on $pkgname template.\n"
		fi
	done

	if [ -n "$only_for_archs" ]; then
		if $(echo "$only_for_archs"|grep -q "$XBPS_MACHINE"); then
			found=1
		fi
	fi
	if [ -n "${only_for_archs}" -a -z "$found" ]; then
		msg_error "$pkgname: this package cannot be built on $XBPS_MACHINE.\n"
	fi

	if [ -n "$build_requires" ]; then
		local xbpssrcver=$(xbps-src -V)
		$XBPS_CMPVER_CMD $build_requires $xbpssrcver
		if [ $? -eq 1 ]; then
			msg_error "$pkgname: xbps-src-${build_requires} is required to build this pkg!\n"
		fi
	fi

	unset XBPS_EXTRACT_DONE XBPS_APPLYPATCHES_DONE
	unset XBPS_CONFIGURE_DONE XBPS_BUILD_DONE XBPS_INSTALL_DONE

	[ -z "$wrksrc" ] && wrksrc="$pkgname-$version"
	wrksrc="$XBPS_BUILDDIR/$wrksrc"

	XBPS_FETCH_DONE="$wrksrc/.xbps_fetch_done"
	XBPS_EXTRACT_DONE="$wrksrc/.xbps_extract_done"
	XBPS_APPLYPATCHES_DONE="$wrksrc/.xbps_applypatches_done"
	XBPS_CONFIGURE_DONE="$wrksrc/.xbps_configure_done"
	XBPS_PRECONFIGURE_DONE="$wrksrc/.xbps_pre_configure_done"
	XBPS_POSTCONFIGURE_DONE="$wrksrc/.xbps_post_configure_done"
	XBPS_BUILD_DONE="$wrksrc/.xbps_build_done"
	XBPS_PRE_BUILD_DONE="$wrksrc/.xbps_pre_build_done"
	XBPS_POST_BUILD_DONE="$wrksrc/.xbps_post_build_done"
	XBPS_INSTALL_DONE="$wrksrc/.xbps_install_done"
	XBPS_PRE_INSTALL_DONE="$wrksrc/.xbps_pre_install_done"
	XBPS_POST_INSTALL_DONE="$wrksrc/.xbps_post_install_done"

	set_tmpl_common_vars
}

remove_tmpl_wrksrc() {
	local lwrksrc="$1"

	if [ -d "$lwrksrc" ]; then
		msg_normal "$pkgver: cleaning build directory...\n"
		rm -rf $lwrksrc
	fi
}

set_tmpl_common_vars() {
	local cflags= cxxflags= cppflags= ldflags= j= _pkgdep= _pkgdepname= _deps=

	[ -z "$pkgname" ] && return 1

	if [ -n "$revision" ]; then
		pkgver="${pkgname}-${version}_${revision}"
	else
		pkgver="${pkgname}-${version}"
	fi

	. $XBPS_SHUTILSDIR/install_files.sh

	FILESDIR=$XBPS_SRCPKGDIR/$pkgname/files
	PATCHESDIR=$XBPS_SRCPKGDIR/$pkgname/patches
	DESTDIR=${XBPS_DESTDIR}/${pkgname}-${version}
	if [ -z "${sourcepkg}" ]; then
		sourcepkg=${pkgname}
	fi
	SRCPKGDESTDIR=${XBPS_DESTDIR}/${sourcepkg}-${version}

	if [ -z "$SUBPKG" ]; then
		_deps="${depends} ${fulldepends}"
	else
		_deps="${depends}"
	fi
	for j in ${_deps}; do
		_pkgdepname="$($XBPS_PKGDB_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		run_depends="${run_depends} ${_pkgdep}"
	done
	for j in ${makedepends} ${fulldepends}; do
		_pkgdepname="$($XBPS_PKGDB_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		build_depends="${build_depends} ${_pkgdep}"
	done

	[ -n "$XBPS_CFLAGS" ] && cflags="$XBPS_CFLAGS"
	[ -n "$CFLAGS" ] && cflags="$cflags $CFLAGS"
	[ -n "$XBPS_CXXFLAGS" ] && cxxflags="$XBPS_CXXFLAGS"
	[ -n "$CXXFLAGS" ] && cxxflags="$cxxflags $CXXFLAGS"
	[ -n "$XBPS_CPPFLAGS" ] && cppflags="$XBPS_CPPFLAGS"
	[ -n "$CPPFLAGS" ] && cppflags="$cppflags $CPPFLAGS"
	[ -n "$XBPS_LDFLAGS" ] && ldflags="$XBPS_LDFLAGS"
	[ -n "$LDFLAGS" ] && ldflags="$ldflags $LDFLAGS"

	[ -n "$cflags" ] && export CFLAGS="$cflags"
	[ -n "$cxxflags" ] && export CXXFLAGS="$cxxflags"
	[ -n "$cppflags" ] && export CPPFLAGS="$cppflags"
	[ -n "$ldflags" ] && export LDFLAGS="$ldflags"

	if [ -n "$broken_as_needed" -a -n "$XBPS_LDFLAGS" ]; then
		export LDFLAGS="$(echo $LDFLAGS|sed -e "s|-Wl,--as-needed||g")"
	fi

	if [ -z "$IN_CHROOT" ]; then
		export CPPFLAGS="-I$XBPS_MASTERDIR/usr/include"
		if [ -d /usr/lib/libfakeroot ]; then
			LDLIBPATH="/usr/lib/libfakeroot:$XBPS_MASTERDIR/usr/lib"
		else
			LDLIBPATH="$XBPS_MASTERDIR/usr/lib"
		fi
		if [ -n "$BUILD_32BIT" ]; then
			# Force gcc multilib to emit 32bit binaries.
			export CC="gcc -m32"
			export CXX="g++ -m32"
			# Export default 32bit directories.
			LDLIBPATH="$LDLIBPATH:/lib32:/usr/lib32"
			LDFLAGS="-L/lib32 -L/usr/lib32"
		fi
		export LDFLAGS="$LDFLAGS -L$XBPS_MASTERDIR/usr/lib"
		export LD_LIBRARY_PATH="$LDLIBPATH"
	fi
}

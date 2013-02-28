# -*-* shell *-*-
#
# Resets all vars used by a template.
#
reset_tmpl_vars() {
	local TMPL_VARS="pkgname distfiles configure_args strip_cmd \
			make_build_args make_install_args build_style	\
			short_desc maintainer long_desc checksum wrksrc	\
			make_cmd bootstrap register_shell \
			make_build_target configure_script noextract nofetch \
			nostrip nonfree build_requires disable_debug \
			make_install_target version revision patch_args \
			sgml_catalogs xml_catalogs xml_entries sgml_entries \
			disable_parallel_build font_dirs preserve \
			only_for_archs conf_files keep_libtool_archives \
			noarch subpackages sourcepkg triggers make_dirs \
			replaces system_accounts system_groups provides \
			build_wrksrc create_wrksrc broken_as_needed pkgver \
			ignore_vdeps_dir noverifyrdeps conflicts dkms_modules \
			pycompile_dirs pycompile_module systemd_services  \
			homepage license kernel_hooks_version makejobs \
			mutable_files nostrip_files skip_extraction \
			softreplace create_srcdir run_depends build_depends \
			depends makedepends fulldepends crossmakedepends \
			SUBPKG XBPS_EXTRACT_DONE XBPS_CONFIGURE_DONE \
			XBPS_BUILD_DONE XBPS_INSTALL_DONE FILESDIR DESTDIR \
			SRCPKGDESTDIR PATCHESDIR CFLAGS CXXFLAGS CPPFLAGS \
			CC CXX LDFLAGS LD_LIBRARY_PATH"

	local TMPL_FUNCS="pre_configure pre_build pre_install do_build \
			  do_install do_configure do_fetch post_configure \
			  post_build post_install post_extract"

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

	REQ_VARS="pkgname version short_desc revision homepage license"

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

	if [ -n "$BEGIN_INSTALL" -a -n "$only_for_archs" ]; then
		if [ -n "$XBPS_CROSS_BUILD" ]; then
			if $(echo "$only_for_archs"|grep -q "$XBPS_TARGET_MACHINE"); then
				found=1
			fi
		else
			if $(echo "$only_for_archs"|grep -q "$XBPS_MACHINE"); then
				found=1
			fi
		fi
		if [ -z "$found" ]; then
			msg_red "$pkgname: this package cannot be built on $XBPS_MACHINE.\n"
			exit 0
		fi
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

	pkgver="${pkgname}-${version}_${revision}"

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
		_pkgdepname="$($XBPS_UHELPER_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdepname="$($XBPS_UHELPER_CMD getpkgname ${j} 2>/dev/null)"
		fi

		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		run_depends="${run_depends} ${_pkgdep}"
	done
	for j in ${makedepends} ${fulldepends}; do
		_pkgdepname="$($XBPS_UHELPER_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdepname="$($XBPS_UHELPER_CMD getpkgname ${j} 2>/dev/null)"
		fi
		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		build_depends="${build_depends} ${_pkgdep}"
	done
	for j in ${crossmakedepends}; do
		_pkgdepname="$($XBPS_UHELPER_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdepname="$($XBPS_UHELPER_CMD getpkgname ${j} 2>/dev/null)"
		fi
		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		cross_build_depends="${cross_build_depends} ${_pkgdep}"
	done

	# For nonfree/bootstrap pkgs there's no point in building -dbg pkgs, disable them.
	if [ -n "$nonfree" -o -n "$bootstrap" ]; then
		disable_debug=yes
	fi

	# -g is required to build -dbg packages.
	if [ -z "$disable_debug" ]; then
		DEBUG_CFLAGS="-g"
	fi

	if [ -n "$XBPS_MAKEJOBS" -a -z "$disable_parallel_build" ]; then
		makejobs="-j$XBPS_MAKEJOBS"
	fi

	export CFLAGS="$XBPS_CFLAGS $XBPS_CROSS_CFLAGS $CFLAGS $DEBUG_CFLAGS"
	export CXXFLAGS="$XBPS_CXXFLAGS $XBPS_CROSS_CXXFLAGS $CXXFLAGS $DEBUG_CFLAGS"
	export CPPFLAGS="$XBPS_CPPFLAGS $XBPS_CROSS_CPPFLAGS $CPPFLAGS"
	export LDFLAGS="$LDFLAGS $XBPS_LDFLAGS $XBPS_CROSS_LDFLAGS"

	if [ -n "$broken_as_needed" -a -n "$XBPS_LDFLAGS" ]; then
		export LDFLAGS="$(echo $LDFLAGS|sed -e "s|-Wl,--as-needed||g")"
	fi

	if [ -n "$XBPS_CROSS_BUILD" ]; then
		export CC="${XBPS_CROSS_TRIPLET}-gcc"
		export CXX="${XBPS_CROSS_TRIPLET}-c++"
		export CPP="${XBPS_CROSS_TRIPLET}-cpp"
		export GCC="$CC"
		export LD="${XBPS_CROSS_TRIPLET}-ld"
		export AR="${XBPS_CROSS_TRIPLET}-ar"
		export AS="${XBPS_CROSS_TRIPLET}-as"
		export RANLIB="${XBPS_CROSS_TRIPLET}-ranlib"
		export STRIP="${XBPS_CROSS_TRIPLET}-strip"
		export OBJDUMP="${XBPS_CROSS_TRIPLET}-objdump"
		export OBJCOPY="${XBPS_CROSS_TRIPLET}-objcopy"
		export NM="${XBPS_CROSS_TRIPLET}-nm"
		export READELF="${XBPS_CROSS_TRIPLET}-readelf"
	else
		export CC="cc"
		export CXX="g++"
		export CPP="cpp"
		export GCC="$CC"
		export LD="ld"
		export AR="ar"
		export AS="as"
		export RANLIB="ranlib"
		export STRIP="strip"
		export OBJDUMP="objdump"
		export OBJCOPY="objcopy"
		export NM="nm"
		export READELF="readelf"
	fi

	if [ -z "$IN_CHROOT" ]; then
		export CPPFLAGS="-I$XBPS_MASTERDIR/usr/include"
		if [ -d /usr/lib/libfakeroot ]; then
			LDLIBPATH="/usr/lib/libfakeroot:$XBPS_MASTERDIR/usr/lib"
		else
			LDLIBPATH="$XBPS_MASTERDIR/usr/lib"
		fi
		export LDFLAGS="$LDFLAGS -L$XBPS_MASTERDIR/usr/lib"
		export LD_LIBRARY_PATH="$LDLIBPATH"
	fi
}

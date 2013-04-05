# -*-* shell *-*-

run_func() {
	local func="$1" restoretrap= logpipe= logfile= teepid=

	if [ -d "${wrksrc}" ]; then
		logpipe=$(mktemp -u --tmpdir=${wrksrc} .xbps_${XBPS_CROSS_TRIPLET}_XXXXXXXX.logpipe)
		logfile=${wrksrc}/.xbps_${XBPS_CROSS_TRIPLET}_${func}.log
	else
		logpipe=$(mktemp -u .xbps_${XBPS_CROSS_TRIPLET}_${func}_${pkgname}_logpipe.XXXXXXX)
		logfile=$(mktemp -t .xbps_${XBPS_CROSS_TRIPLET}_${func}_${pkgname}.log.XXXXXXXX)
	fi

	msg_normal "$pkgver: running $func ...\n"

	set -E
	restoretrap=$(trap -p ERR)
	trap 'error_func $func $LINENO' ERR

	mkfifo "$logpipe"
	tee "$logfile" < "$logpipe" &
	teepid=$!

	$func &>"$logpipe"

	wait $teepid
	rm "$logpipe"

	eval "$restoretrap"
	set +E
}

error_func() {
	if [ -n "$1" -a -n "$2" ]; then
		msg_red "$pkgver: failed to run $1() at line $2.\n"
	fi
	exit 2
}

msg_red() {
	# error messages in bold/red
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	if [ -n "$IN_CHROOT" ]; then
		printf >&2 "[chroot] => ERROR: $@"
	else
		printf >&2 "=> ERROR: $@"
	fi
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_red_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	printf >&2 "$@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_error() {
	msg_red "$@"
	kill -INT $$; exit 1
}

msg_error_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	printf >&2 "=> ERROR: $@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
	exit 1
}

msg_warn() {
	# warn messages in bold/yellow
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
	if [ -n "$IN_CHROOT" ]; then
		printf >&2 "[chroot] => WARNING: $@"
	else
		printf >&2 "=> WARNING: $@"
	fi
	[ -n "$NOCOLORS" ] || printf >&2  "\033[m"
}

msg_warn_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
	printf >&2 "=> WARNING: $@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_normal() {
	# normal messages in bold
	[ -n "$NOCOLORS" ] || printf "\033[1m"
	if [ -n "$IN_CHROOT" ]; then
		printf "[chroot] => $@"
	else
		printf "=> $@"
	fi
	[ -n "$NOCOLORS" ] || printf "\033[m"
}

msg_normal_append() {
	[ -n "$NOCOLORS" ] || printf "\033[1m"
	printf "$@"
	[ -n "$NOCOLORS" ] || printf "\033[m"
}


set_build_options() {
	local f j opt optval _optsset
	local -A options

	[ ! -f $XBPS_SRCPKGDIR/$pkgname/template.options ] && return 0

	. $XBPS_SRCPKGDIR/$pkgname/template.options

	for f in ${build_options}; do
		OIFS="$IFS"; IFS=','
		for j in ${XBPS_BUILD_OPTS}; do
			opt=${j#\~}
			opt_disabled=${j:0:1}
			if [ "$opt" = "$f" ]; then
				if [ "$opt_disabled" != "~" ]; then
					options[$opt]=1
				else
					options[$opt]=0
				fi
			fi
		done
		IFS="$OIFS"
	done

	for f in ${build_options_default}; do
		optval=${options[$f]}
		if [[ -z "$optval" ]] || [[ $optval -eq 1 ]]; then
			options[$f]=1
		fi
	done

	# Prepare final options.
	for f in ${!options[@]}; do
		optval=${options[$f]}
		[[ $optval -eq 1 ]] && eval build_option_${f}=1
	done

	if declare -f do_options >/dev/null; then
		do_options
	fi

	for f in ${build_options}; do
		optval=${options[$f]}
		if [[ $optval -eq 1 ]]; then
			state=enabled
			_optsset="${_optsset} ${f}"
		else
			state=disabled
			_optsset="${_optsset} ~${f}"
		fi
	done

	for f in ${_optsset}; do
		if [ -z "$PKG_BUILD_OPTIONS" ]; then
			PKG_BUILD_OPTIONS="$f"
		else
			PKG_BUILD_OPTIONS="$PKG_BUILD_OPTIONS $f"
		fi
	done

	export PKG_BUILD_OPTIONS
}

reset_pkg_vars() {
	local TMPL_VARS="pkgname distfiles configure_args \
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
			softreplace create_srcdir \
			depends fulldepends makedepends hostmakedepends \
			run_depends build_depends host_build_depends \
			build_options build_options_default \
			SUBPKG XBPS_EXTRACT_DONE XBPS_CONFIGURE_DONE \
			XBPS_BUILD_DONE XBPS_INSTALL_DONE FILESDIR DESTDIR \
			SRCPKGDESTDIR PATCHESDIR CFLAGS CXXFLAGS CPPFLAGS \
			CC CXX LDFLAGS LD_LIBRARY_PATH PKG_BUILD_OPTIONS"

	local TMPL_FUNCS="pre_configure pre_build pre_install do_build \
			  do_install do_configure do_fetch post_configure \
			  post_build post_install post_extract"

	eval unset -v "$TMPL_VARS"
	eval unset -f "$TMPL_FUNCS"
}

reset_subpkg_vars() {
        local VARS="nonfree conf_files noarch triggers replaces softreplace \
			system_accounts system_groups preserve \
			xml_entries sgml_entries xml_catalogs sgml_catalogs \
			font_dirs dkms_modules provides kernel_hooks_version \
			conflicts pycompile_dirs pycompile_module \
			systemd_services make_dirs depends run_depends"

	eval unset -v "$VARS"
}

setup_pkg() {
	local pkg="$1"

	[ -z "$pkg" ] && return 1

	if [ -f $XBPS_SRCPKGDIR/${pkg}/template ]; then
		reset_pkg_vars
		. $XBPS_SRCPKGDIR/${pkg}/template
		sourcepkg=$pkgname
		pkgver="${pkgname}-${version}_${revision}"
		set_build_options
		set_pkg_common_vars
	else
		msg_error "Cannot find $pkg build template file.\n"
	fi

	if [ -z "$wrksrc" ]; then
		wrksrc="$XBPS_BUILDDIR/${pkgname}-${version}"
	else
		wrksrc="$XBPS_BUILDDIR/$wrksrc"
	fi

}

setup_subpkg() {
	local f=

	[ -z "$1" ] && return 1

	if [ -r "$XBPS_SRCPKGDIR/$1/$1.template" ]; then
		setup_pkg $1
		unset build_depends host_build_depends
		reset_subpkg_vars
		. $XBPS_SRCPKGDIR/$1/$1.template
		for f in ${subpackages}; do
			[ "$f" != "$1" ] && continue
			pkgname=$f
			pkgver="${pkgname}-${version}_${revision}"
			SUBPKG=1
			set_pkg_common_vars
			break
		done
	else
		setup_pkg $1
	fi
}

setup_pkg_build_vars() {
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
}

set_pkg_common_vars() {
	local i= _pkgdep= _pkgdepname= _deps= REQ_VARS=

	[ -z "$pkgname" ] && return 1

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

	FILESDIR=$XBPS_SRCPKGDIR/$pkgname/files
	PATCHESDIR=$XBPS_SRCPKGDIR/$pkgname/patches

	if [ -n "$XBPS_CROSS_BUILD" ]; then
		DESTDIR=${XBPS_DESTDIR}/${XBPS_CROSS_TRIPLET}/${pkgname}-${version}
		SRCPKGDESTDIR=${XBPS_DESTDIR}/${XBPS_CROSS_TRIPLET}/${sourcepkg}-${version}
	else
		DESTDIR=${XBPS_DESTDIR}/${pkgname}-${version}
		SRCPKGDESTDIR=${XBPS_DESTDIR}/${sourcepkg}-${version}
	fi

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
	for j in ${hostmakedepends} ${fulldepends}; do
		_pkgdepname="$($XBPS_UHELPER_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdepname="$($XBPS_UHELPER_CMD getpkgname ${j} 2>/dev/null)"
		fi
		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		host_build_depends="${host_build_depends} ${_pkgdep}"
	done
	for j in ${makedepends}; do
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
}

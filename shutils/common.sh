# -*-* shell *-*-

run_func() {
	local func="$1" restoretrap= logpipe= logfile= teepid=

	if [ -d "${wrksrc}" ]; then
		logpipe=$(mktemp -u --tmpdir=${wrksrc} .xbps_${XBPS_CROSS_BUILD}_XXXXXXXX.logpipe)
		logfile=${wrksrc}/.xbps_${XBPS_CROSS_BUILD}_${func}.log
	else
		logpipe=$(mktemp -u .xbps_${XBPS_CROSS_BUILD}_${func}_${pkgname}_logpipe.XXXXXXX)
		logfile=$(mktemp -t .xbps_${XBPS_CROSS_BUILD}_${func}_${pkgname}.log.XXXXXXXX)
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

	if [ -z "$build_options" ]; then
		return 0
	fi

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
		if [[ $optval -eq 1 ]]; then
			eval build_option_${f}=1
		fi
	done

	# Re-read pkg template to get conditional vars.
	if [ -z "$XBPS_BUILD_OPTIONS_PARSED" ]; then
		source_file $XBPS_SRCPKGDIR/$pkgname/template
		XBPS_BUILD_OPTIONS_PARSED=1
		unset PKG_BUILD_OPTIONS
		set_build_options
		return 0
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
			depends makedepends hostmakedepends \
			run_depends build_depends host_build_depends \
			build_options build_options_default \
			SUBPKG XBPS_EXTRACT_DONE XBPS_CONFIGURE_DONE \
			XBPS_BUILD_DONE XBPS_INSTALL_DONE FILESDIR DESTDIR \
			PKGDESTDIR PATCHESDIR CFLAGS CXXFLAGS CPPFLAGS \
			XBPS_CROSS_CFLAGS XBPS_CROSS_CXXFLAGS \
			XBPS_CROSS_CPPFLAGS XBPS_CROSS_LDFLAGS \
			CC CXX LDFLAGS LD_LIBRARY_PATH PKG_BUILD_OPTIONS"

	local TMPL_FUNCS="pre_configure pre_build pre_install do_build \
			  do_install do_configure do_fetch post_configure \
			  post_build post_install post_extract"

	for f in ${subpackages}; do
		eval unset -f ${f}_package
	done

	eval unset -v "$TMPL_VARS"
	eval unset -f "$TMPL_FUNCS"
}

reset_subpkg_vars() {
        local VARS="nonfree conf_files noarch triggers replaces softreplace \
			system_accounts system_groups preserve \
			xml_entries sgml_entries xml_catalogs sgml_catalogs \
			font_dirs dkms_modules provides kernel_hooks_version \
			conflicts pycompile_dirs pycompile_module \
			systemd_services make_dirs depends run_depends \
			pkg_install"

	eval unset -v "$VARS"
}

source_file() {
	local f="$1"

	if ! source "$f"; then
		msg_error "xbps-src: failed to read $f!\n"
	fi
}

get_subpkgs() {
	local args list

	args="$(typeset -F|grep -E '_package$')"
	set -- ${args}
	while [ $# -gt 0 ]; do
		# Add sourcepkg at bottom
		if [ "${3%_package}" = "$sourcepkg" ]; then
			shift 3; continue
		fi
		list+=" ${3%_package}"; shift 3
	done

	list+=" $sourcepkg"
	for f in ${list}; do
		echo "$f"
	done
}

setup_pkg_reqvars() {
	local cross="$1"

	if [ -n "$cross" ]; then
		source_file $XBPS_CROSSPFDIR/${cross}.sh

		REQ_VARS="TARGET_ARCH CROSS_TRIPLET CROSS_CFLAGS CROSS_CXXFLAGS"
		for i in ${REQ_VARS}; do
			eval val="\$XBPS_$i"
			if [ -z "$val" ]; then
				echo "ERROR: XBPS_$i is not defined!"
				exit 1
			fi
		done

		export XBPS_CROSS_BASE=/usr/$XBPS_CROSS_TRIPLET

		XBPS_INSTALL_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_INSTALL_CMD -c /host/repocache -r $XBPS_CROSS_BASE"
		XBPS_QUERY_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_QUERY_CMD -c /host/repocache -r $XBPS_CROSS_BASE"
		XBPS_RECONFIGURE_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_RECONFIGURE_CMD -r $XBPS_CROSS_BASE"
		XBPS_REMOVE_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_REMOVE_CMD -r $XBPS_CROSS_BASE"
		XBPS_RINDEX_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_RINDEX_CMD"
		XBPS_UHELPER_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH xbps-uhelper -r $XBPS_CROSS_BASE"

		export XBPS_TARGET_MACHINE=$XBPS_TARGET_ARCH
	else
		XBPS_INSTALL_XCMD="$XBPS_INSTALL_CMD"
		XBPS_QUERY_XCMD="$XBPS_QUERY_CMD"
		XBPS_RECONFIGURE_XCMD="$XBPS_RECONFIGURE_CMD"
		XBPS_REMOVE_XCMD="$XBPS_REMOVE_CMD"
		XBPS_RINDEX_XCMD="$XBPS_RINDEX_CMD"
		XBPS_UHELPER_XCMD="$XBPS_UHELPER_CMD"

		export XBPS_TARGET_MACHINE=$XBPS_MACHINE

		unset XBPS_CROSS_BASE XBPS_CROSS_LDFLAGS
		unset XBPS_CROSS_CFLAGS XBPS_CROSS_CXXFLAGS XBPS_CROSS_CPPFLAGS
	fi

	export XBPS_INSTALL_XCMD XBPS_QUERY_XCMD XBPS_RECONFIGURE_XCMD \
		XBPS_REMOVE_XCMD XBPS_RINDEX_XCMD XBPS_UHELPER_XCMD
}

setup_pkg() {
	local pkg="$1" cross="$2" restorecross

	[ -z "$pkg" ] && return 1

	if [ ! -f $XBPS_SRCPKGDIR/${pkg}/template ]; then
		msg_error "Cannot find $pkg build template file.\n"
	fi

	reset_pkg_vars
	setup_pkg_reqvars $cross

	if [ -n "$cross" ]; then
		export CROSS_BUILD="$cross"
		source_file $XBPS_SRCPKGDIR/${pkg}/template
		install_cross_pkg $cross || return 1
	else
		unset CROSS_BUILD
		source_file $XBPS_SRCPKGDIR/${pkg}/template
	fi

	sourcepkg=$pkgname
	subpackages="$(get_subpkgs)"

	if [ -h $XBPS_SRCPKGDIR/$pkg ]; then
		# subpkg
		reset_subpkg_vars
		pkgname=$pkg
		if ! declare -f ${pkg}_package >/dev/null; then
			msg_error "$pkgname: cannot find pkg ${pkg}_package() function!\n"
		fi
		${pkg}_package
		SUBPKG=1
	fi

	pkgver="${pkg}-${version}_${revision}"

	# Check that there's a ${pkgname}_pkg function matching $pkgname.
	if ! declare -f ${sourcepkg}_package >/dev/null; then
		msg_error "$sourcepkg: ${sourcepkg}_package() function not defined!\n"
	fi

	setup_pkg_common_vars $pkg $cross
	set_build_options

	if [ -z "$wrksrc" ]; then
		wrksrc="$XBPS_BUILDDIR/${sourcepkg}-${version}"
	else
		wrksrc="$XBPS_BUILDDIR/$wrksrc"
	fi
}

setup_pkg_depends() {
	local pkg="$1" j _pkgdepname _pkgdep

	if [ -n "$pkg" ]; then
		# subpkg
		if declare -f ${pkg}_package >/dev/null; then
			${pkg}_package
		fi
	fi

	for j in ${depends}; do
		_pkgdepname="$($XBPS_UHELPER_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdepname="$($XBPS_UHELPER_CMD getpkgname ${j} 2>/dev/null)"
		fi

		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		run_depends+=" ${_pkgdep}"
	done
	for j in ${hostmakedepends}; do
		_pkgdepname="$($XBPS_UHELPER_CMD getpkgdepname ${j} 2>/dev/null)"
		if [ -z "${_pkgdepname}" ]; then
			_pkgdepname="$($XBPS_UHELPER_CMD getpkgname ${j} 2>/dev/null)"
		fi
		if [ -z "${_pkgdepname}" ]; then
			_pkgdep="$j>=0"
		else
			_pkgdep="$j"
		fi
		host_build_depends+=" ${_pkgdep}"
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
		build_depends+=" ${_pkgdep}"
	done
}

setup_pkg_common_vars() {
	local pkg="$1" cross="$2" val i REQ_VARS dbgflags

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

	FILESDIR=$XBPS_SRCPKGDIR/$sourcepkg/files
	PATCHESDIR=$XBPS_SRCPKGDIR/$sourcepkg/patches
	DESTDIR=$XBPS_DESTDIR/$XBPS_CROSS_TRIPLET/${sourcepkg}-${version}
	PKGDESTDIR=$XBPS_DESTDIR/$XBPS_CROSS_TRIPLET/pkg-${pkg}-${version}

	if [ -n "$XBPS_MAKEJOBS" -a -z "$disable_parallel_build" ]; then
		makejobs="-j$XBPS_MAKEJOBS"
	fi

	# For nonfree/bootstrap pkgs there's no point in building -dbg pkgs, disable them.
	if [ -z "$XBPS_DEBUG_PKGS" -o -n "$nonfree" -o -n "$bootstrap" ]; then
		disable_debug=yes
	fi

	# -g is required to build -dbg packages.
	if [ -z "$disable_debug" ]; then
		dbgflags="-g"
	fi

	export CFLAGS="$XBPS_CFLAGS $XBPS_CROSS_CFLAGS $CFLAGS $dbgflags"
	export CXXFLAGS="$XBPS_CXXFLAGS $XBPS_CROSS_CXXFLAGS $CXXFLAGS $dbgflags"
	export CPPFLAGS="$XBPS_CPPFLAGS $XBPS_CROSS_CPPFLAGS $CPPFLAGS"
	export LDFLAGS="$LDFLAGS $XBPS_LDFLAGS $XBPS_CROSS_LDFLAGS"

	if [ -n "$cross" ]; then
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

_remove_pkg_cross_deps() {
	local rval= tmplogf=
	[ -z "$XBPS_CROSS_BUILD" ] && return 0

	cd $XBPS_MASTERDIR || return 1
	msg_normal "${pkgver:-xbps-src}: removing autocrossdeps, please wait...\n"
	tmplogf=$(mktemp)

	if [ -z "$XBPS_REMOVE_XCMD" ]; then
		source_file $XBPS_CROSSPFDIR/${XBPS_CROSS_BUILD}.sh
		XBPS_REMOVE_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH xbps-remove -r /usr/$XBPS_CROSS_TRIPLET"
	fi

	$FAKEROOT_CMD $XBPS_REMOVE_XCMD -Ryo > $tmplogf 2>&1
	if [ $? -ne 0 ]; then
		msg_red "${pkgver:-xbps-src}: failed to remove autocrossdeps:\n"
		cat $tmplogf && rm -f $tmplogf
		msg_error "${pkgver:-xbps-src}: cannot continue!\n"
	fi
	rm -f $tmplogf
}


remove_pkg_autodeps() {
	local rval= tmplogf=

	[ -z "$CHROOT_READY" ] && return 0

	cd $XBPS_MASTERDIR || return 1
	msg_normal "${pkgver:-xbps-src}: removing autodeps, please wait...\n"
	tmplogf=$(mktemp)

	( $FAKEROOT_CMD xbps-reconfigure -a;
	  $FAKEROOT_CMD xbps-remove -Ryo; ) >> $tmplogf 2>&1

	if [ $? -ne 0 ]; then
		msg_red "${pkgver:-xbps-src}: failed to remove autodeps:\n"
		cat $tmplogf && rm -f $tmplogf
		msg_error "${pkgver:-xbps-src}: cannot continue!\n"
	fi
	rm -f $tmplogf

	_remove_pkg_cross_deps
}

install_cross_pkg() {
	local cross="$1"

	[ -z "$cross" -o "$cross" = "" ] && return 0

	if [ ! -r ${XBPS_CROSSPFDIR}/${cross}.sh ]; then
		echo "ERROR: missing cross build profile for ${cross}, exiting."
		exit 1
	fi

	source_file ${XBPS_CROSSPFDIR}/${cross}.sh

	if [ -z "$CHROOT_READY" ]; then
		echo "ERROR: chroot mode not activated (install a bootstrap)."
		exit 1
	elif [ -z "$IN_CHROOT" ]; then
		return 0
	fi

	# Install required pkgs for cross building.
	if [ "$XBPS_TARGET" != "remove-autodeps" ]; then
		check_installed_pkg cross-${XBPS_CROSS_TRIPLET}-0.1_1
		if [ $? -ne 0 ]; then
			echo "Installing required cross pkg: cross-${XBPS_CROSS_TRIPLET}"
			$XBPS_INSTALL_CMD -Ay cross-${XBPS_CROSS_TRIPLET} 2>&1 >/dev/null
			if [ $? -ne 0 ]; then
				echo "ERROR: failed to install cross-${XBPS_CROSS_TRIPLET}"
				exit 1
			fi
		fi
		$XBPS_INSTALL_CMD -r /usr/${XBPS_CROSS_TRIPLET} \
			-Sy cross-vpkg-dummy 2>&1 >/dev/null
		if [ $? -ne 0 -a $? -ne 6 ]; then
			echo "ERROR: failed to install cross-vpkg-dummy"
			exit 1
		fi
	fi
}

#
# Returns 0 if pkgpattern in $1 is installed and greater than current
# installed package, otherwise 1.
#
check_installed_pkg() {
	local pkg="$1" cross="$2" uhelper= pkgn= iver=

	[ -z "$pkg" ] && return 2

	pkgn="$($XBPS_UHELPER_CMD getpkgname ${pkg})"
	[ -z "$pkgn" ] && return 2

	if [ -n "$cross" ]; then
		uhelper="$XBPS_UHELPER_XCMD"
	else
		uhelper="$XBPS_UHELPER_CMD"
	fi

	iver="$($uhelper version $pkgn)"
	if [ $? -eq 0 -a -n "$iver" ]; then
		$XBPS_CMPVER_CMD "${pkgn}-${iver}" "${pkg}"
		[ $? -eq 0 -o $? -eq 1 ] && return 0
	fi

	return 1
}

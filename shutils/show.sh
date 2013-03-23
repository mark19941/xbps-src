# -*-* shell *-*-
#
# Shows info about a template.
#
show_tmpl() {
	local i=

	echo "pkgname:	$pkgname"
	echo "version:	$version"
	echo "revision:	$revision"
	for i in ${distfiles}; do
		[ -n "$i" ] && echo "distfiles:	$i"
	done
	for i in ${checksum}; do
		[ -n "$i" ] && echo "checksum:	$i"
	done
	[ -n "$noarch" ] && echo "noarch:		yes"
	echo "maintainer:	$maintainer"
	[ -n "$homepage" ] && echo "Upstream URL:	$homepage"
	[ -n "$license" ] && echo "License(s):	$license"
	[ -n "$build_style" ] && echo "build_style:	$build_style"
	for i in ${configure_args}; do
		[ -n "$i" ] && echo "configure_args:	$i"
	done
	echo "short_desc:	$short_desc"
	for i in ${subpackages}; do
		[ -n "$i" ] && echo "subpackages:	$i"
	done
	for i in ${conf_files}; do
		[ -n "$i" ] && echo "conf_files:	$i"
	done
	for i in ${replaces}; do
		[ -n "$i" ] && echo "replaces:	$i"
	done
	for i in ${provides}; do
		[ -n "$i" ] && echo "provides:	$i"
	done
	for i in ${conflicts}; do
		[ -n "$i" ] && echo "conflicts:	$i"
	done
	[ -n "$long_desc" ] && echo "long_desc: $long_desc"
}

show_tmpl_deps() {
	[ -f "${DESTDIR}/rdeps" ] && cat ${DESTDIR}/rdeps
}

show_tmpl_build_deps() {
	local f=

	# build time deps
	for f in ${build_depends}; do
		echo "$f"
	done
}

show_tmpl_options() {
	local f= j= state= desc= enabled=

	if [ -f $XBPS_SRCPKGDIR/$pkgname/template.options ]; then
		. $XBPS_SRCPKGDIR/$pkgname/template.options
		for f in ${build_options}; do
			for j in ${build_options_default}; do
				if [ "$f" = "$j" ]; then
					enabled=1
					break
				fi
			done
			state="OFF"
			if [ -n "$enabled" ]; then
				state="ON"
				unset enabled
			fi
			eval desc="\$desc_option_$f"
			printf "$f: $desc [$state]\n"
		done
	fi
}

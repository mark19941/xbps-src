# -*-* shell *-*-

strip_files()
{
	local subpkg=

	for subpkg in ${subpackages}; do
		. $XBPS_SRCPKGDIR/${sourcepkg}/${subpkg}.template
		pkgname=${subpkg}
		set_tmpl_common_vars
		strip_files_real
		setup_tmpl ${sourcepkg}
	done

	strip_files_real
}

make_debug() {
	local dname= fname= dbgfile=

	[ -n "$disable_debug" ] && return

	dname=$(echo "$(dirname $1)"|sed -e "s|${DESTDIR}||g")
	fname="$(basename $1)"
	dbgfile="${dname}/${fname}"

	[ -z "${objcopy_cmd}" ] && objcopy_cmd=objcopy

	vmkdir "usr/lib/debug/${dname}"
	${objcopy_cmd} --only-keep-debug --compress-debug-sections \
		"$1" "${DESTDIR}/usr/lib/debug/${dbgfile}" || \
		msg_error "${pkgver}: failed to create dbg file: ${dbgfile}\n"
	chmod 644 "${DESTDIR}/usr/lib/debug/${dbgfile}"
}

attach_debug() {
	local dname= fname= dbgfile=

	[ -n "$disable_debug" ] && return

	dname=$(echo "$(dirname $1)"|sed -e "s|${DESTDIR}||g")
	fname="$(basename $1)"
	dbgfile="${dname}/${fname}"

	[ -z "${objcopy_cmd}" ] && objcopy_cmd=objcopy

	${objcopy_cmd} --add-gnu-debuglink="${DESTDIR}/usr/lib/debug/${dbgfile}" "$1" || \
		msg_error "${pkgver}: failed to attach dbg to ${dbgfile}\n"
}

create_debug_pkg() {
	local _pkgname=

	[ -n "$disable_debug" ] && return
	[ ! -d "${DESTDIR}/usr/lib/debug" ] && return

	_pkgname="${pkgname}-dbg"
	mkdir -p "${XBPS_DESTDIR}/${_pkgname}-${version}/usr/lib"
	mv ${DESTDIR}/usr/lib/debug  \
		${XBPS_DESTDIR}/${_pkgname}-${version}/usr/lib
}

strip_files_real()
{
	local f= x= found= fname=

	[ -n "$nostrip" -o -n "$noarch" ] && return 0
	[ -z "$strip_cmd" ] && strip_cmd=strip

	msg_normal "$pkgver: creating debug files and stripping, please wait...\n"
	find ${DESTDIR} -type f | while read f; do
		fname=$(basename "$f")
		for x in ${nostrip_files}; do
			if [ "$x" = "$fname" ]; then
				found=1
				break
			fi
		done
		if [ -n "$found" ]; then
			unset found
			continue
		fi
		case "$(file -bi "$f")" in
		application/x-executable*)
			if echo "$(file $f)" | grep -q "statically linked"; then
				# static binary
				${strip_cmd} "$f" && \
					echo "    Stripped static executable: $fname"
			else
				make_debug "$f"
				${strip_cmd} "$f" && echo "   Stripped executable: $fname"
				attach_debug "$f"
			fi
			;;
		application/x-sharedlib*)
			# shared library
			make_debug "$f"
			${strip_cmd} --strip-unneeded "$f" && echo "   Stripped library: $fname"
			attach_debug "$f"
			;;
		application/x-archive*)
			${strip_cmd} --strip-debug "$f" && \
				echo "   Stripped static library: $fname";;
		esac
	done

	# Create a subpkg with debug files.
	create_debug_pkg
}

#!/bin/bash
#
# Passed arguments:
#	$1 - pkgname [REQUIRED]
#	$2 - cross target [OPTIONAL]

make_debug() {
	local dname= fname= dbgfile=

	[ -n "$disable_debug" ] && return 0

	dname=$(echo "$(dirname $1)"|sed -e "s|${PKGDESTDIR}||g")
	fname="$(basename $1)"
	dbgfile="${dname}/${fname}"

	mkdir -p "${PKGDESTDIR}/usr/lib/debug/${dname}"
	$OBJCOPY --only-keep-debug --compress-debug-sections \
		"$1" "${PKGDESTDIR}/usr/lib/debug/${dbgfile}"
	if [ $? -ne 0 ]; then
		msg_red "${pkgver}: failed to create dbg file: ${dbgfile}\n"
		return 1
	fi
	chmod 644 "${PKGDESTDIR}/usr/lib/debug/${dbgfile}"
}

attach_debug() {
	local dname= fname= dbgfile=

	[ -n "$disable_debug" ] && return 0

	dname=$(echo "$(dirname $1)"|sed -e "s|${PKGDESTDIR}||g")
	fname="$(basename $1)"
	dbgfile="${dname}/${fname}"

	$OBJCOPY --add-gnu-debuglink="${PKGDESTDIR}/usr/lib/debug/${dbgfile}" "$1"
	if [ $? -ne 0 ]; then
		msg_red "${pkgver}: failed to attach dbg to ${dbgfile}\n"
		return 1
	fi
}

create_debug_pkg() {
	local _pkgname= _destdir=

	[ -n "$disable_debug" ] && return 0
	[ ! -d "${PKGDESTDIR}/usr/lib/debug" ] && return 0

	_pkgname="${pkgname}-dbg-${version}"
	_destdir="${XBPS_DESTDIR}/${XBPS_CROSS_TRIPLET}/${_pkgname}"
	mkdir -p "${_destdir}/usr/lib"
	mv ${PKGDESTDIR}/usr/lib/debug ${_destdir}/usr/lib
	if [ $? -ne 0 ]; then
		msg_red "$pkgver: failed to create debug pkg\n"
		return 1
	fi
	rmdir "${PKGDESTDIR}/usr/lib" 2>/dev/null
	return 0
}

pkg_strip() {
	local fname= x= f= _soname=

	msg_normal "$pkgver: creating debug files and stripping, please wait...\n"
	find ${PKGDESTDIR} -type f | while read f; do
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
				$STRIP "$f"
				if [ $? -ne 0 ]; then
					msg_red "$pkgver: failed to strip ${f#$PKGDESTDIR}\n"
					return 1
				fi
				echo "   Stripped static executable: ${f#$PKGDESTDIR}"
			else
				make_debug "$f"
				$STRIP "$f"
				if [ $? -ne 0 ]; then
					msg_red "$pkgver: failed to strip ${f#$PKGDESTDIR}\n"
					return 1
				fi
				echo "   Stripped executable: ${f#$PKGDESTDIR}"
				attach_debug "$f"
			fi
			;;
		application/x-sharedlib*)
			# shared library
			make_debug "$f"
			$STRIP --strip-unneeded "$f"
			if [ $? -ne 0 ]; then
				msg_red "$pkgver: failed to strip ${f#$PKGDESTDIR}\n"
				return 1
			fi
			echo "   Stripped library: ${f#$PKGDESTDIR}"
			_soname=$(objdump -p "$f"|grep SONAME|awk '{print $2}')
			if [ -n "${_soname}" ]; then
				echo "${_soname}" >> ${PKGDESTDIR}/.shlib-provides
			fi
			attach_debug "$f"
			;;
		application/x-archive*)
			$STRIP --strip-debug "$f"
			if [ $? -ne 0 ]; then
				msg_red "$pkgver: failed to strip ${f#$PKGDESTDIR}\n"
				return 1
			fi
			echo "   Stripped static library: ${f#$PKGDESTDIR}";;
		esac
	done

	if [ -s "$PKGDESTDIR/.shlib-provides" ]; then
		cat $PKGDESTDIR/.shlib-provides | tr '\n' ' ' > $PKGDESTDIR/shlib-provides
		echo >> $PKGDESTDIR/shlib-provides
		rm -f $PKGDESTDIR/.shlib-provides
	fi

	return $?
}

if [ $# -lt 1 -o $# -gt 2 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname [cross-target]"
	exit 1
fi

PKGNAME="$1"
XBPS_CROSS_BUILD="$2"

. $XBPS_SHUTILSDIR/common.sh
. $XBPS_SHUTILSDIR/install_files.sh

for f in $XBPS_COMMONDIR/*.sh; do
	. $f
done

setup_pkg "$PKGNAME" $XBPS_CROSS_BUILD

if [ "$sourcepkg" != "$PKGNAME" ]; then
	${PKGNAME}_package
	pkgname=$PKGNAME
fi

if [ -n "$nostrip" -o -n "$noarch" ]; then
	exit 0
fi

XBPS_STRIP_DONE="$wrksrc/.xbps_${PKGNAME}_${XBPS_CROSS_BUILD}_strip_done"

if [ -f "$XBPS_STRIP_DONE" ]; then
	exit 0
fi

if [ ! -d "$PKGDESTDIR" ]; then
	msg_error "$pkgver: cannot access $PKGDESTDIR!\n"
fi

pkg_strip || exit $?
# Create a subpkg with debug files.
create_debug_pkg || exit $?

touch -f $XBPS_STRIP_DONE

exit 0

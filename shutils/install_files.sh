# -*-* shell *-*-

vinstall() {
	local file="$1" mode="$2" targetdir="$3" targetfile="$4"
	local _destdir=

	if [ -z "$DESTDIR" ]; then
		msg_red "$pkgver: vinstall: DESTDIR unset, can't continue...\n"
		return 1
	fi

	if [ $# -lt 3 ]; then
		msg_red "$pkgver: vinstall: 3 arguments expected: <file> <mode> <target-directory>\n"
		return 1
	fi

	if [ ! -r "$file" ]; then
		msg_red "$pkgver: vinstall: cannot find '$file'...\n"
		return 1
	fi

	if [ -n "$XBPS_PKGDESTDIR" ]; then
		_destdir="$PKGDESTDIR"
	else
		_destdir="$DESTDIR"
	fi

	if [ -z "$targetfile" ]; then
		install -Dm${mode} ${file} "${_destdir}/${targetdir}/$(basename ${file})"
	else
		install -Dm${mode} ${file} "${_destdir}/${targetdir}/$(basename ${targetfile})"
	fi
}

vcopy() {
	local files="$1" targetdir="$2"

	if [ -z "$DESTDIR" ]; then
		msg_red "$pkgver: vcopy: DESTDIR unset, can't continue...\n"
		return 1
	fi
	if [ $# -ne 2 ]; then
		msg_red "$pkgver: vcopy: 2 arguments expected: <files> <target-directory>\n"
		return 1
	fi

	cp -a $files ${DESTDIR}/${targetdir}
}

vmove() {
	local files="$1" _targetdir

	if [ -z "$DESTDIR" ]; then
		msg_red "$pkgver: vmove: DESTDIR unset, can't continue...\n"
		return 1
	elif [ -z "$PKGDESTDIR" ]; then
		msg_red "$pkgver: vmove: PKGDESTDIR unset, can't continue...\n"
		return 1
	fi
	if [ $# -ne 1 ]; then
		msg_red "$pkgver: vmove: 1 argument expected: <files>\n"
		return 1
	fi
	for f in ${files}; do
		_targetdir=$(dirname $f)
		break
	done

	if [ -z "${_targetdir}" ]; then
		[ ! -d ${PKGDESTDIR} ] && install -d ${PKGDESTDIR}
		mv ${DESTDIR}/$files ${PKGDESTDIR}
	else
		if [ ! -d ${PKGDESTDIR}/${_targetdir} ]; then
			install -d ${PKGDESTDIR}/${_targetdir}
		fi
		mv ${DESTDIR}/$files ${PKGDESTDIR}/${_targetdir}
	fi
}

vmkdir() {
	local dir="$1" mode="$2"

	if [ -z "$DESTDIR" ]; then
		msg_red "$pkgver: vmkdir: DESTDIR unset, can't continue...\n"
		return 1
	fi

	if [ -z "$dir" ]; then
		msg_red "vmkdir: directory argument unset.\n"
		return 1
	fi

	if [ -z "$mode" ]; then
		install -d ${DESTDIR}/${dir}
	else
		install -dm${mode} ${DESTDIR}/${dir}
	fi
}

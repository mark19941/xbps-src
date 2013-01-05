# -*-* shell *-*-

vinstall() {
	local file="$1" mode="$2" targetdir="$3" targetfile="$4"

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

	if [ -z "$targetfile" ]; then
		install -Dm${mode} ${file} "${DESTDIR}/${targetdir}/$(basename ${file})"
	else
		install -Dm${mode} ${file} "${DESTDIR}/${targetdir}/$(basename ${targetfile})"
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
	local files="$1" targetdir="$2"

	if [ -z "$DESTDIR" ]; then
		msg_red "$pkgver: vmove: DESTDIR unset, can't continue...\n"
		return 1
	elif [ -z "$SRCPKGDESTDIR" ]; then
		msg_red "$pkgver: vmove: SRCPKGDESTDIR unset, can't continue...\n"
		return 1
	fi
	if [ $# -lt 1 ]; then
		msg_red "$pkgver: vmove: 1 argument expected: <files>\n"
		return 1
	fi
	if [ -z "${targetdir}" ]; then
		[ ! -d ${DESTDIR} ] && install -d ${DESTDIR}
		mv ${SRCPKGDESTDIR}/$files ${DESTDIR}
	else
		[ ! -d ${DESTDIR}/${targetdir} ] && vmkdir ${targetdir}
		mv ${SRCPKGDESTDIR}/$files ${DESTDIR}/${targetdir}
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

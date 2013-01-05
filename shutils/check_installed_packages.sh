# -*-* shell *-*-
#
# Check installed package versions against the source packages repository.
#
check_installed_packages() {
	local f= lpkgn= lpkgver= rv= srcpkgver= srcver=

	for f in $(${XBPS_QUERY_CMD} -l|awk '{print $2}'); do
		lpkgn=$(${XBPS_UHELPER_CMD} getpkgname ${f})
		lpkgver=$(${XBPS_UHELPER_CMD} getpkgversion ${f})

		if [ -r ${XBPS_SRCPKGDIR}/${lpkgn}/${lpkgn}.template ]; then
			. ${XBPS_SRCPKGDIR}/${lpkgn}/template
			sourcepkg=$pkgname
			. ${XBPS_SRCPKGDIR}/${lpkgn}/${lpkgn}.template
		else
			if [ ! -r ${XBPS_SRCPKGDIR}/${lpkgn}/template ]; then
				continue
			fi
			. ${XBPS_SRCPKGDIR}/${lpkgn}/template
		fi
		srcver="${version}_${revision}"
		${XBPS_CMPVER_CMD} ${lpkgver} ${srcver}
		if [ $? -eq 255 ]; then
			echo "pkgname: ${lpkgn} masterdir: ${lpkgver} srcpkgs: ${srcver}"
		fi
		unset pkgname version revision
	done
}

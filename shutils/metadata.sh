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

write_metadata() {
	local subpkg=

	for subpkg in ${subpackages}; do
		if [ ! -f $XBPS_SRCPKGDIR/${sourcepkg}/${subpkg}.template ]; then
			msg_error "$pkgver: cannot find subpkg '${subpkg}' build template!\n"
		fi
		setup_tmpl ${sourcepkg}
		unset conf_files noarch triggers replaces softreplace \
			system_accounts system_groups \
			preserve xml_entries sgml_entries \
			xml_catalogs sgml_catalogs \
			font_dirs dkms_modules provides \
			kernel_hooks_version conflicts pycompile_dirs \
			pycompile_module systemd_services make_dirs \
			depends fulldepends run_depends mutable_files
		. $XBPS_SRCPKGDIR/${sourcepkg}/${subpkg}.template
		pkgname=${subpkg}
		set_tmpl_common_vars
		write_metadata_real || return $?
	done

	setup_tmpl ${sourcepkg}
	write_metadata_real || return $?
	return $?
}

#
# This function writes the metadata files into package's destdir,
# these will be used for binary packages.
#
write_metadata_real() {
	local f= i= j= found= arch= dirat= lnkat= newlnk=
	local lver= TMPFLIST= TMPFPLIST=
	local fpattern="s|${DESTDIR}||g;s|^\./$||g;/^$/d"

	if [ ! -d "${DESTDIR}" ]; then
		msg_error "$pkgver: not installed in destdir!\n"
	fi

	if [ -n "$noarch" ]; then
		arch=noarch
	else
		arch=$XBPS_MACHINE
	fi

	lver="${version}_${revision}"

	#
	# Always remove metadata files generated in a previous installation.
	#
	for f in INSTALL REMOVE files.plist props.plist flist rdeps; do
		[ -f ${DESTDIR}/${f} ] && rm -f ${DESTDIR}/${f}
	done

	#
	# If package provides virtual packages, create dynamically the
	# required configuration file.
	#
	if [ -n "$provides" ]; then
		_tmpf=$(mktemp) || msg_error "$pkgver: failed to create tempfile.\n"
		echo "# Virtual packages provided by '${pkgname}':" >>${_tmpf}
		for f in ${provides}; do
			echo "virtual-package ${pkgname} { targets = \"${f}\" }" >>${_tmpf}
		done
		install -Dm644 ${_tmpf} \
			${DESTDIR}/etc/xbps/virtualpkg.d/${pkgname}.conf
		rm -f ${_tmpf}
	fi

        #
        # Find out if this package contains info files and compress
        # all them with gzip.
        #
	if [ -f ${DESTDIR}/usr/share/info/dir ]; then
		# Always remove this file if curpkg is not texinfo.
		if [ "$pkgname" != "texinfo" ]; then
			[ -f ${DESTDIR}/usr/share/info/dir ] && \
				rm -f ${DESTDIR}/usr/share/info/dir
		fi
		# Add info-files trigger.
		triggers="info-files $triggers"
		msg_normal "$pkgver: processing info(1) files...\n"

		find ${DESTDIR}/usr/share/info -type f -follow | while read f
		do
			j=$(echo "$f"|sed -e "$fpattern")
			[ "$j" = "" ] && continue
			[ "$j" = "/usr/share/info/dir" ] && continue
			# Ignore compressed files.
			if $(echo "$j"|grep -q '.*.gz$'); then
				continue
			fi
			# Ignore non info files.
			if ! $(echo "$j"|grep -q '.*.info$') && \
			   ! $(echo "$j"|grep -q '.*.info-[0-9]*$'); then
				continue
			fi
			if [ -h ${DESTDIR}/"$j" ]; then
				dirat=$(dirname "$j")
				lnkat=$(readlink ${DESTDIR}/"$j")
				newlnk=$(basename "$j")
				rm -f ${DESTDIR}/"$j"
				cd ${DESTDIR}/"$dirat"
				ln -s "${lnkat}".gz "${newlnk}".gz
				continue
			fi
			echo "   Compressing info file: $j..."
			gzip -nfq9 ${DESTDIR}/"$j"
		done
	fi

	#
	# Find out if this package contains manual pages and
	# compress all them with gzip.
	#
	if [ -d "${DESTDIR}/usr/share/man" ]; then
		msg_normal "$pkgver: processing manual pages...\n"
		find ${DESTDIR}/usr/share/man -type f -follow | while read f
		do
			j=$(echo "$f"|sed -e "$fpattern")
			[ "$j" = "" ] && continue
			if $(echo "$j"|grep -q '.*.gz$'); then
				continue
			fi
			if [ -h ${DESTDIR}/"$j" ]; then
				dirat=$(dirname "$j")
				lnkat=$(readlink ${DESTDIR}/"$j")
				newlnk=$(basename "$j")
				rm -f ${DESTDIR}/"$j"
				cd ${DESTDIR}/"$dirat"
				ln -s "${lnkat}".gz "${newlnk}".gz
				continue
			fi
			echo "   Compressing manpage: $j..."
			gzip -nfq9 ${DESTDIR}/"$j"
		done
	fi

	#
	# Create package's flist for bootstrap packages.
	#
	find ${DESTDIR} -print > ${DESTDIR}/flist
	sed -i -e "s|${DESTDIR}||g;s|/flist||g;/^$/d" ${DESTDIR}/flist

	#
	# Create package's fdeps to know its run-time dependencies.
	#
	verify_rundeps ${DESTDIR}

	#
	# If package sets $dkms_modules, add dkms rundep.
	#
	if [ -n "$dkms_modules" ]; then
		run_depends="${run_depends} dkms>=0"
	fi

	#
	# If package sets $system_accounts or $system_groups, add shadow rundep.
	#
	if [ -n "$system_accounts" -o -n "$system_groups" ]; then
		run_depends="${run_depends} shadow>=0"
	fi

	[ -n "$run_depends" ] && echo "${run_depends}" > ${DESTDIR}/rdeps

	#
	# Create the INSTALL/REMOVE scripts if package uses them
	# or uses any available trigger.
	#
	local meta_install meta_remove
	if [ -n "${sourcepkg}" -a "${sourcepkg}" != "${pkgname}" ]; then
		meta_install=${XBPS_SRCPKGDIR}/${pkgname}/${pkgname}.INSTALL
		meta_remove=${XBPS_SRCPKGDIR}/${pkgname}/${pkgname}.REMOVE
	else
		meta_install=${XBPS_SRCPKGDIR}/${pkgname}/INSTALL
		meta_remove=${XBPS_SRCPKGDIR}/${pkgname}/REMOVE
	fi
	write_metadata_scripts install ${meta_install} || \
		msg_error "$pkgver: failed to write INSTALL metadata file!\n"

	write_metadata_scripts remove ${meta_remove} || \
		msg_error "$pkgver: failed to write REMOVE metadata file!\n"

	msg_normal "$pkgver: successfully created package metadata.\n"
}

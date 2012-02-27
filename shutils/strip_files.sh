#-
# Copyright (c) 2010-2012 Juan Romero Pardines.
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

strip_files_real()
{
	local f= x= found= fname=

	[ -n "$nostrip" -o -n "$noarch" ] && return 0
	[ -z "$strip_cmd" ] && strip_cmd=strip

	msg_normal "$pkgver: stripping files, please wait...\n"
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
			${strip_cmd} "$f" && \
				echo "   Stripped executable: $fname";;
		application/x-sharedlib*)
			${strip_cmd} --strip-unneeded "$f" && \
				echo "   Stripped library: $fname";;
		application/x-archive*)
			${strip_cmd} --strip-debug "$f" && \
				echo "   Stripped static library: $fname";;
		esac
	done
}

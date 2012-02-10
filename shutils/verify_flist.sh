#-
# Copyright (c) 2012 Juan Romero Pardines.
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
#
# Verify inconsistencies in package's files list. If any file installed
# by a package hasn't been found in <pkgname>.flist inform the user and
# error out.
#

verify_flist()
{
	local metadir=$DESTDIR/var/db/xbps/metadata/$pkgname
	local flist=$XBPS_SRCPKGDIR/$pkgname/$pkgname.flist
	local f j x found flist_modified

	[ -z "$pkgname" ] && return 1
	[ "$build_style" = "meta-template" ] && return 0
	[ ! -f $metadir/flist ] && return 1

	if [ ! -f $flist ]; then
		# If no flist exists, create it.
		for f in $(cat $metadir/flist); do
			[ -d $DESTDIR/$f ] && continue
			echo "$f" >>$flist
		done
		msg_normal "$pkgver: created package's flist.\n"
		return 0
	fi

	# Check for new files/links in DESTDIR.
	msg_normal "$pkgver: checking for new files in destdir, please wait...\n"

	for f in $(cat $metadir/flist); do
		unset found
		# ignore directories.
		[ -d $DESTDIR/$f ] && continue
		# Check in shared flist.
		for j in $(cat $flist); do
			if [ "$f" = "$j" ]; then
				found=1
				break
			fi
		done
		# Check in arch flist.
		if [ -f "${flist}.${XBPS_MACHINE}" ]; then
			for j in $(cat ${flist}.${XBPS_MACHINE}); do
				if [ "$f" = "$j" ]; then
					found=1
					break
				fi
			done
		fi
		# file unmatched, update flist.
		if [ -z "$found" ]; then
			flist_modified=1
			echo "   $f"
		fi
	done

	# Check for obsolete files/links found in $pkgname.flist.
	msg_normal "$pkgver: checking for obsolete files in flist, please wait...\n"
	for f in $(cat $flist); do
		unset found
		if [ -f "${flist}.${XBPS_MACHINE}" ]; then
			for x in $(cat ${flist}.${XBPS_MACHINE}); do
				for j in $(cat $metadir/flist); do
					if [ "$f" = "$j" -o "$x" = "$j" ]; then
						found=1
						break
					fi
				done
			done
		else
			for j in $(cat $metadir/flist); do
				if [ "$f" = "$j" ]; then
					found=1
					break
				fi
			done
		fi
		if [ -z "$found" ]; then
			# file in flist but not in DESTDIR.
			flist_modified=1
			echo "   $f"
		fi
	done

	[ -z "$flist_modified" ] && return 0

	msg_red "$pkgver: package's files list has changed!\n"
	msg_red "  Please check why the files list changed and bump the revision\n"
	msg_red "  number in package's template file if you are sure it's ok.\n"
	msg_red "  If you don't know what to do, please contact the package maintainer.\n"
	msg_red "$pkgver: can't continue due to flist change!\n"
	return 1
}

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

#
# Extracts contents of distfiles specified in a template into
# the $wrksrc directory.
#
extract_distfiles() {
	local pkg="$1" curfile= cursufx= f= j= found=
	local srcdir=

	[ -f $XBPS_EXTRACT_DONE ] && return 0
	[ -z "$IN_CHROOT" -a ! -w $XBPS_BUILDDIR ] && \
		msg_error "$pkgver: can't extract distfile(s) (permission denied)\n"

	#
	# If we are being called via the target, just extract and return.
	#
	[ -n "$pkg" -a -z "$pkgname" ] && return 1

	#
	# If noextract is set, do a "fake extraction".
	#
	if [ -z "$distfiles" -o -n "$noextract" ]; then
		[ ! -d "$wrksrc" ] && mkdir -p $wrksrc
		run_func do_extract
		touch -f $XBPS_EXTRACT_DONE
		return 0
	fi
	if [ -n "$create_srcdir" ]; then
		srcdir="$XBPS_SRCDISTDIR/$pkgname-$version"
	else
		srcdir="$XBPS_SRCDISTDIR"
	fi

	# Check that distfiles are there before anything else.
	for f in ${distfiles}; do
		curfile=$(basename $f)
		if [ ! -f $srcdir/$curfile ]; then
			msg_error "$pkgver: cannot find ${curfile}, use 'xbps-src fetch' first.\n"
		fi
	done

	if [ -n "$create_wrksrc" ]; then
		mkdir -p ${wrksrc} || return 1
	fi

	msg_normal "$pkgver: extracting distfile(s), please wait...\n"

	for f in ${distfiles}; do
		curfile=$(basename $f)
		for j in ${skip_extraction}; do
			if [ "$curfile" = "$j" ]; then
				found=1
				break
			fi
		done
		if [ -n "$found" ]; then
			unset found
			continue
		fi

		if $(echo $f|grep -q '.tar.lzma'); then
			cursufx="txz"
		elif $(echo $f|grep -q '.tar.xz'); then
			cursufx="txz"
		elif $(echo $f|grep -q '.txz'); then
			cursufx="txz"
		elif $(echo $f|grep -q '.tar.bz2'); then
			cursufx="tbz"
		elif $(echo $f|grep -q '.tbz'); then
			cursufx="tbz"
		elif $(echo $f|grep -q '.tar.gz'); then
			cursufx="tgz"
		elif $(echo $f|grep -q '.tgz'); then
			cursufx="tgz"
		elif $(echo $f|grep -q '.gz'); then
			cursufx="gz"
		elif $(echo $f|grep -q '.bz2'); then
			cursufx="bz2"
		elif $(echo $f|grep -q '.tar'); then
			cursufx="tar"
		elif $(echo $f|grep -q '.zip'); then
			cursufx="zip"
		else
			msg_error "$pkgver: unknown distfile suffix for $curfile.\n"
		fi

		if [ -n "$create_wrksrc" ]; then
			extractdir="$wrksrc"
		else
			extractdir="$XBPS_BUILDDIR"
		fi

		case ${cursufx} in
		txz)
			unxz -cf $srcdir/$curfile | tar xf - -C $extractdir
			if [ $? -ne 0 ]; then
				msg_error "$pkgver: extracting $curfile into $XBPS_BUILDDIR.\n"
			fi
			;;
		tbz)
			bunzip2 -cf $srcdir/$curfile | tar xf - -C $extractdir
			if [ $? -ne 0 ]; then
				msg_error "$pkgver: extracting $curfile into $XBPS_BUILDDIR.\n"
			fi
			;;
		tgz)
			gunzip -cf $srcdir/$curfile | tar xf - -C $extractdir
			if [ $? -ne 0 ]; then
				msg_error "$pkgver: extracting $curfile into $XBPS_BUILDDIR.\n"
			fi
			;;
		gz|bz2)
			cp -f $srcdir/$curfile $extractdir
			if [ "$cursufx" = ".gz" ]; then
				cd $extractdir && gunzip $curfile
			else
				cd $extractdir && bunzip2 $curfile
			fi
			;;
		tar)
			tar xf $srcdir/$curfile -C $extractdir
			if [ $? -ne 0 ]; then
				msg_error "$pkgver: extracting $curfile into $XBPS_BUILDDIR.\n"
			fi
			;;
		zip)
			if command -v unzip 2>&1 >/dev/null; then
				unzip -q $srcdir/$curfile -d $extractdir
				if [ $? -ne 0 ]; then
					msg_error "$pkgver: extracting $curfile into $XBPS_BUILDDIR.\n"
				fi
			else
				msg_error "$pkgver: cannot find unzip bin for extraction.\n"
			fi
			;;
		*)
			msg_error "$pkgver: cannot guess $curfile extract suffix. ($cursufx)\n"
			;;
		esac
	done

	touch -f $XBPS_FETCH_DONE
	touch -f $XBPS_EXTRACT_DONE

	run_func post_extract
	return 0
}

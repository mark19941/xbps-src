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

stow_pkg_handler() {
	local action="$1" subpkg=

	for subpkg in ${subpackages}; do
		if [ ! -f $XBPS_SRCPKGDIR/${sourcepkg}/${subpkg}.template ]; then
			msg_error "$pkgver: cannot find $subpkg subpkg build template!\n"
		fi
		unset pre_install pre_remove post_install \
			post_remove post_stow
		. $XBPS_SRCPKGDIR/${sourcepkg}/${subpkg}.template
		pkgname=${subpkg}
		set_tmpl_common_vars
		if [ "$action" = "stow" ]; then
			stow_pkg_real || return $?
		else
			unstow_pkg_real || return $?
		fi
		setup_tmpl ${sourcepkg}
	done

	if [ "$action" = "stow" ]; then
		stow_pkg_real
	else
		unstow_pkg_real
	fi
	return $?
}

#
# Stow a package, i.e copy/symlink files from destdir into masterdir
# and register pkg into pkgdb.
#
stow_pkg_real() {
	local i= lfile= lver= regpkgdb_flags= flist=

	[ -z "$pkgname" ] && return 2

	flist=$XBPS_PKGMETADIR/$pkgname/flist

	if [ -f "$flist" ]; then
		msg_normal "$pkgver: already stowed.\n"
		return 0
	fi
	if [ $(id -u) -ne 0 ] && [ ! -w $XBPS_MASTERDIR ]; then
		msg_error "$pkgver: cannot be stowed! (permission denied)\n"
	fi

	if [ -n "$build_style" -a "$build_style" = "meta-template" ]; then
		[ ! -d ${DESTDIR} ] && mkdir -p ${DESTDIR}
	fi

	[ -n "$stow_flag" ] && setup_tmpl $pkgname

	cd ${DESTDIR} || return 1

	if [ -n "$revision" ]; then
		lver="${version}_${revision}"
	else
		lver="${version}"
	fi
	msg_normal "$pkgver: stowing files into masterdir, please wait...\n"

	local metadir=$(dirname $flist)
	[ ! -d $metadir ] && mkdir -p $metadir
	[ -f $flist ] && rm -f $flist
	touch -f $flist

	# Copy files into masterdir.
	for i in $(find -print); do
		lfile="$(echo $i|sed -e 's|^\./||')"
		# Skip pkg metadata
		if [ "$lfile" = "INSTALL" -o "$lfile" = "REMOVE" -o \
		     "$lfile" = "files.plist" -o "$lfile" = "props.plist" ]; then
		     continue
		# Skip flist from pkg's destdir
		elif [ "$(basename $i)" = "flist" ]; then
			continue
		# Skip files that are already in masterdir.
		elif [ -f "$XBPS_MASTERDIR/$lfile" ]; then
			echo "   Skipping $lfile file, already exists!"
			continue
		elif [ -h "$XBPS_MASTERDIR/$lfile" ]; then
			echo "   Skipping $lfile link, already exists!"
			continue
		elif [ -d "$XBPS_MASTERDIR/$lfile" ]; then
			continue
		fi
		if [ -f "$i" -o -h "$i" ]; then
			cp -dp $i $XBPS_MASTERDIR/$lfile
			[ $? -eq 0 ] && echo "$lfile" >>$flist
		elif [ -d "$i" ]; then
			mkdir -p $XBPS_MASTERDIR/$lfile
		fi
	done

	#
	# Register pkg in pkgdb.
	#
	$XBPS_PKGDB_CMD register $pkgname $lver "$short_desc" || return $?
	run_func post_stow
	return 0
}

#
# Unstow a package, i.e remove its files from masterdir and
# unregister pkg from pkgdb.
#
unstow_pkg_real() {
	local f= ver= flist=

	[ -z $pkgname ] && return 1

	if [ $(id -u) -ne 0 ] && \
	   [ ! -w $XBPS_MASTERDIR ]; then
		msg_error "$pkgver: cannot be unstowed! (permission denied)\n"
	fi

	ver=$($XBPS_PKGDB_CMD version $pkgname)
	if [ -z "$ver" ]; then
		msg_warn "'${pkgname}' not installed in masterdir!\n"
		return 1
	fi

	flist=$XBPS_PKGMETADIR/$pkgname/flist

	if [ "$build_style" = "meta-template" ]; then
		# If it's a metapkg, do nothing.
		:
	elif [ ! -f $flist ]; then
		msg_warn "${pkgname}-${ver}: wasn't installed from source!\n"
		return 1
	elif [ ! -w $flist ]; then
		msg_error "${pkgname}-${ver}: cannot be removed (permission denied).\n"
	elif [ -s $flist ]; then
		msg_normal "${pkgname}-${ver}: removing files from masterdir...\n"
		run_func pre_remove
		# Remove installed files.
		for f in $(cat $flist); do
			if [ -f $XBPS_MASTERDIR/$f ]; then
				rm -f $XBPS_MASTERDIR/$f >/dev/null 2>&1
				[ $? -eq 0 ] && echo "Removed file: $f"
			elif [ -h $XBPS_MASTERDIR/$f ]; then
				rm -f $XBPS_MASTERDIR/$f >/dev/null 2>&1
				[ $? -eq 0 ] && echo "Removed link: $f"
			elif  [ -d $XBPS_MASTERDIR/$f ]; then
				rmdir $XBPS_MASTERDIR/$f >/dev/null 2>&1
				[ $? -eq 0 ] && echo "Removed directory: $f"
			fi
		done
	fi

	run_func post_remove
	# Remove metadata directory in masterdir.
	[ -d $XBPS_PKGMETADIR/$pkgname ] && rm -rf $XBPS_PKGMETADIR/$pkgname

	# Unregister pkg from pkgdb.
	$XBPS_PKGDB_CMD unregister $pkgname $ver
	return $?
}

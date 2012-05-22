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
# Check binary package versions against the source packages version.

check_repository_packages() {
	local f= tmpl= subtmpl= pkgn= binpkgver= srcpkgver=

	if [ -n "$IN_CHROOT" ]; then
		XREPOCMD="$XBPS_REPO_CMD"
	else
		XREPOCMD="xbps-repo"
	fi

	for f in $(find $XBPS_SRCPKGDIR -type f -name \*template); do
		tmpl=${f%.template}
		subtmpl=$(basename "$tmpl")
		if [ "$subtmpl" = "template" ]; then
			pkgn=$(basename $(dirname $tmpl))
		else
			pkgn=$(basename $subtmpl)
		fi
		binpkgver=$($XREPOCMD show -oversion $pkgn 2>/dev/null)
		[ $? -ne 0 ] && continue

		if [ -r $XBPS_SRCPKGDIR/$pkgn/${pkgn}.template ]; then
			. $XBPS_SRCPKGDIR/$pkgn/template
			sourcepkg=$pkgname
			. $XBPS_SRCPKGDIR/$pkgn/$pkgn.template
		else
			. $XBPS_SRCPKGDIR/$pkgn/template
		fi
		if [ -n "$revision" ]; then
			srcpkgver="${version}_${revision}"
		else
			srcpkgver="${version}"
		fi
		$XBPS_CMPVER_CMD ${binpkgver} ${srcpkgver}
		if [ $? -eq 255 ]; then
			echo "pkgname: ${pkgn} repover: ${binpkgver} srcpkgver: ${srcpkgver}"
		fi
		reset_tmpl_vars
	done
}

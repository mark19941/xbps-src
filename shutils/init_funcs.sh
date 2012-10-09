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

set_defvars() {
	local DDIRS= i= xbps_conf=

	XBPS_HELPERSDIR=$XBPS_SHAREDIR/helpers
	XBPS_SHUTILSDIR=$XBPS_SHAREDIR/shutils
	XBPS_META_PATH=$XBPS_MASTERDIR/var/db/xbps
	XBPS_PKGMETADIR=$XBPS_META_PATH/metadata

	if [ -n "$IN_CHROOT" ]; then
		XBPS_SRCPKGDIR=/xbps/srcpkgs
		XBPS_COMMONDIR=/xbps/common
		XBPS_DESTDIR=/destdir
		XBPS_BUILDDIR=/builddir
	else
		XBPS_SRCPKGDIR=$XBPS_DISTDIR/srcpkgs
		XBPS_COMMONDIR=$XBPS_DISTDIR/common
		XBPS_DESTDIR=$XBPS_MASTERDIR/destdir
		XBPS_BUILDDIR=$XBPS_MASTERDIR/builddir
	fi
	if [ -n "$XBPS_HOSTDIR" ]; then
		XBPS_PACKAGESDIR=$XBPS_HOSTDIR/binpkgs
		XBPS_SRCDISTDIR=$XBPS_HOSTDIR/sources
	else
		XBPS_SRCDISTDIR=$XBPS_MASTERDIR/host/sources
		XBPS_PACKAGESDIR=$XBPS_MASTERDIR/host/binpkgs
	fi
	XBPS_TRIGGERSDIR=$XBPS_SRCPKGDIR/xbps-triggers/files

	DDIRS="DISTDIR TRIGGERSDIR HELPERSDIR SRCPKGDIR SHUTILSDIR COMMONDIR"
	for i in ${DDIRS}; do
		eval val="\$XBPS_$i"
		if [ ! -d "$val" ]; then
			echo "WARNING: cannot find $i at $val."
		fi
	done

	for i in DESTDIR PACKAGESDIR BUILDDIR SRCDISTDIR; do
		eval val="\$XBPS_$i"
		if [ ! -d "$val" ]; then
			mdir=$(dirname $XBPS_MASTERDIR)
			[ -z "$IN_CHROOT" -a "$mdir" = "/" ] && continue
			[ -d $XBPS_DISTDIR/.git ] && mkdir -p $val
		fi
	done

	for f in $XBPS_SHUTILSDIR/*.sh $XBPS_COMMONDIR/*.sh; do
		[ -r "$f" ] && . $f
	done
	if [ -n "$IN_CHROOT" ]; then
		xbps_conf="-C /usr/local/etc/xbps/xbps.conf"
	else
		if [ -z "$CHROOT_READY" ]; then
			# We need a non-existent configuration file for
			# -B option to work.
			xbps_conf="-C /empty.conf -B $XBPS_PACKAGESDIR"
		fi
	fi

	if [ -n "$IN_CHROOT" ]; then
		XBPS_BIN=/usr/local/sbin/xbps-bin
		XBPS_REPO=/usr/local/sbin/xbps-repo
		XBPS_PKGDB=/usr/local/sbin/xbps-uhelper
		XBPS_CREATE=/usr/local/sbin/xbps-create
		XBPS_PKGDB_CMD="$XBPS_PKGDB"
		XBPS_BIN_CMD="$XBPS_BIN $xbps_conf"
		XBPS_REPO_CMD="$XBPS_REPO $xbps_conf"
	else
		: ${XBPS_BIN:=xbps-bin}
		: ${XBPS_REPO:=xbps-repo}
		: ${XBPS_PKGDB:=xbps-uhelper}
		: ${XBPS_CREATE:=xbps-create}
		XBPS_PKGDB_CMD="$XBPS_PKGDB -r $XBPS_MASTERDIR"
		XBPS_BIN_CMD="$XBPS_BIN $xbps_conf -r $XBPS_MASTERDIR"
		XBPS_REPO_CMD="$XBPS_REPO $xbps_conf -r $XBPS_MASTERDIR"
	fi

	: ${XBPS_DIGEST_CMD:="$XBPS_PKGDB digest"}
	: ${XBPS_CMPVER_CMD:="$XBPS_PKGDB cmpver"}
	: ${XBPS_FETCH_CMD:="$XBPS_PKGDB fetch"}
	: ${XBPS_CREATE_CMD:=$XBPS_CREATE}

	XBPS_VERSION=$($XBPS_BIN -V|awk '{print $2}')
	XBPS_APIVER=$($XBPS_BIN -V|awk '{print $4}')

	if [ -z "$XBPS_SRC_REQ" -o -z "$XBPS_UTILS_REQ" -o \
	     -z "$XBPS_UTILS_API_REQ" -o -z "$BASE_CHROOT_REQ" ]; then
		echo "ERROR: missing defs from global-defs.sh!"
		exit 1
	fi
	$XBPS_PKGDB_CMD cmpver "$XBPS_SRC_VERSION" "$XBPS_SRC_REQ"
	if [ $? -eq 255 ]; then
		echo "ERROR: this xbps-src version is outdated! (>=$XBPS_SRC_REQ is required)"
		exit 1
	fi
	$XBPS_PKGDB_CMD cmpver "$XBPS_VERSION" "$XBPS_UTILS_REQ"
	if [ $? -eq 255 ]; then
		echo "ERROR: requires xbps-$XBPS_UTILS_REQ API: $XBPS_UTILS_API_REQ"
		exit 1
	fi
	$XBPS_PKGDB_CMD cmpver "$XBPS_APIVER" "$XBPS_UTILS_API_REQ"
	if [ $? -eq 255 ]; then
		echo "ERROR: requires xbps-$XBPS_UTILS_REQ API: $XBPS_UTILS_API_REQ"
		exit 1
	fi

	export XBPS_VERSION XBPS_APIVER XBPS_PKGDB_CMD XBPS_BIN_CMD
	export XBPS_REPO_CMD XBPS_DIGEST_CMD XBPS_CMPVER_CMD XBPS_FETCH_CMD
}

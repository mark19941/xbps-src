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
	local DDIRS= i=

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
		XBPS_INSTALL=/usr/local/sbin/xbps-install
		XBPS_QUERY=/usr/local/sbin/xbps-query
		XBPS_RINDEX=/usr/local/sbin/xbps-rindex
		XBPS_PKGDB=/usr/local/sbin/xbps-uhelper
		XBPS_CREATE=/usr/local/sbin/xbps-create
		XBPS_RECONFIGURE=/usr/local/sbin/xbps-reconfigure
		XBPS_REMOVE=/usr/local/sbin/xbps-remove
		XBPS_PKGDB_CMD="$XBPS_PKGDB"
		XBPS_INSTALL_CMD="$XBPS_INSTALL -C /usr/local/etc/xbps/xbps.conf"
		XBPS_QUERY_CMD="$XBPS_QUERY -C /usr/local/etc/xbps/xbps.conf"
		XBPS_RINDEX_CMD="$XBPS_RINDEX"
		XBPS_RECONFIGURE_CMD="$XBPS_RECONFIGURE -C /usr/local/etc/xbps/xbps.conf"
		XBPS_REMOVE_CMD="$XBPS_REMOVE -C /usr/local/etc/xbps/xbps.conf"
	else
		: ${XBPS_INSTALL:=xbps-install}
		: ${XBPS_QUERY:=xbps-query}
		: ${XBPS_RINDEX:=xbps-rindex}
		: ${XBPS_PKGDB:=xbps-uhelper}
		: ${XBPS_CREATE:=xbps-create}
		: ${XBPS_RECONFIGURE:=xbps-reconfigure}
		: ${XBPS_REMOVE:=xbps-remove}
		XBPS_PKGDB_CMD="$XBPS_PKGDB -r $XBPS_MASTERDIR"
		XBPS_INSTALL_CMD="$XBPS_INSTALL -C /empty.conf -R $XBPS_PACKAGESDIR -r $XBPS_MASTERDIR"
		XBPS_QUERY_CMD="$XBPS_QUERY -C /empty.conf -D $XBPS_PACKAGESDIR -r $XBPS_MASTERDIR"
		XBPS_RINDEX_CMD="$XBPS_RINDEX"
		XBPS_RECONFIGURE_CMD="$XBPS_RECONFIGURE -r $XBPS_MASTERDIR"
		XBPS_REMOVE_CMD="$XBPS_REMOVE -r $XBPS_MASTERDIR"
	fi

	: ${XBPS_DIGEST_CMD:="$XBPS_PKGDB digest"}
	: ${XBPS_CMPVER_CMD:="$XBPS_PKGDB cmpver"}
	: ${XBPS_FETCH_CMD:="$XBPS_PKGDB fetch"}
	: ${XBPS_CREATE_CMD:=$XBPS_CREATE}

	XBPS_VERSION=$($XBPS_PKGDB -V|awk '{print $2}')
	XBPS_APIVER=$($XBPS_PKGDB -V|awk '{print $4}')

	if [ -z "$XBPS_SRC_REQ" -o -z "$XBPS_UTILS_REQ" -o \
	     -z "$XBPS_UTILS_API_REQ" -o -z "$BASE_CHROOT_REQ" ]; then
		echo "ERROR: missing defs from global-defs.sh!"
		exit 1
	fi
	$XBPS_PKGDB_CMD cmpver $(echo "$XBPS_SRC_VERSION"|awk '{print $1}') "$XBPS_SRC_REQ"
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

	export XBPS_VERSION XBPS_APIVER XBPS_PKGDB_CMD XBPS_INSTALL_CMD
	export XBPS_REMOVE_CMD XBPS_RECONFIGURE_CMD XBPS_QUERY_CMD XBPS_RINDEX_CMD
	export XBPS_DIGEST_CMD XBPS_CMPVER_CMD XBPS_FETCH_CMD
}

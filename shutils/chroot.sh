# -*-* shell *-*-

chroot_init() {
	if [ "${CHROOT_CMD}" = "chroot" ]; then
		if [ "$(id -u)" -ne 0 ]; then
			msg_error "Root permissions are required for the chroot, try again."
		fi
	fi

	check_installed_pkg base-chroot-${BASE_CHROOT_REQ%_*}_1
	if [ $? -ne 0 ]; then
		msg_red "${XBPS_MASTERDIR} has not been prepared for chroot operations.\n"
		msg_error "Please install 'base-chroot>=$BASE_CHROOT_REQ' and try again.\n"
	fi

	msg_normal "Starting chroot on $XBPS_MASTERDIR.\n"

	if [ ! -d $XBPS_MASTERDIR/etc/xbps ]; then
		mkdir -p $XBPS_MASTERDIR/etc/xbps
	fi

	XBPSSRC_CF=$XBPS_MASTERDIR/etc/xbps/xbps-src.conf

	cat > $XBPSSRC_CF <<_EOF
# Generated configuration file by xbps-src, DO NOT EDIT!
XBPS_DISTDIR=/xbps
XBPS_MASTERDIR=/
XBPS_CFLAGS="$XBPS_CFLAGS"
XBPS_CXXFLAGS="$XBPS_CXXFLAGS"
XBPS_CPPFLAGS="$XBPS_CPPFLAGS"
XBPS_LDFLAGS="$XBPS_LDFLAGS"
_EOF
	if [ -n "$XBPS_MAKEJOBS" ]; then
		echo "XBPS_MAKEJOBS=$XBPS_MAKEJOBS" >> $XBPSSRC_CF
	fi
	if [ -n "$XBPS_HOSTDIR" ]; then
		echo "XBPS_HOSTDIR=/host" >> $XBPSSRC_CF
	fi
	if [ -n "$XBPS_CCACHE" ]; then
		echo "XBPS_CCACHE=$XBPS_CCACHE" >> $XBPSSRC_CF
	fi
	if [ -n "$XBPS_DISTCC" ]; then
		echo "XBPS_DISTCC=$XBPS_DISTCC" >> $XBPSSRC_CF
		echo "XBPS_DISTCC_HOSTS=\"${XBPS_DISTCC_HOSTS}\"" >> $XBPSSRC_CF
	fi
	if [ -n "$XBPS_USE_GIT_REVS" ]; then
		echo "XBPS_USE_GIT_REVS=yes" >> $XBPSSRC_CF
	fi

	echo "# End of configuration file." >> $XBPSSRC_CF

	if [ -d $XBPS_MASTERDIR/tmp ]; then
		msg_normal "Cleaning up /tmp...\n"
		[ -h ${XBPS_MASTERDIR}/tmp ] || rm -rf $XBPS_MASTERDIR/tmp/*
	fi

	# Create custom script to start the chroot bash shell.
	cat > $XBPS_MASTERDIR/bin/xbps-shell <<_EOF
#!/bin/sh

XBPS_SRC_VERSION="$XBPS_SRC_VERSION"

. /etc/xbps/xbps-src.conf

PATH=/usr/bin:/usr/sbin:/usr/lib/perl5/core_perl/bin

exec env -i PATH="\$PATH" XBPS_ETCDIR="\$XBPS_ETCDIR" \
	XBPS_SHAREDIR="\$XBPS_SHAREDIR" XBPS_LIBEXECDIR="\$XBPS_LIBEXECDIR" \
	XBPS_FETCH_CMD="\$XBPS_FETCH_CMD" XBPS_CMPVER_CMD="\$XBPS_CMPVER_CMD" \
	XBPS_DIGEST_CMD="\$XBPS_DIGEST_CMD" \
	DISTCC_HOSTS="\$XBPS_DISTCC_HOSTS" DISTCC_DIR="/distcc" CCACHE_DIR="/ccache" \
	IN_CHROOT=1 LANG=C TERM=linux PS1="[\u@$XBPS_MASTERDIR \W]$ " /bin/bash +h

_EOF
	chmod 755 $XBPS_MASTERDIR/bin/xbps-shell

	cp -f /etc/resolv.conf $XBPS_MASTERDIR/etc
}

chroot_prepare() {
	local f=

	if [ -f $XBPS_MASTERDIR/.xbps_chroot_init ]; then
		return 0
	elif [ ! -f $XBPS_MASTERDIR/bin/bash ]; then
		msg_error "Bootstrap not installed in $XBPS_MASTERDIR, can't continue.\n"
	fi

	# Create some required files.
	cp -f /etc/services $XBPS_MASTERDIR/etc
	[ -f /etc/localtime ] && cp -f /etc/localtime $XBPS_MASTERDIR/etc

	for f in dev sys proc xbps host boot; do
		[ ! -d $XBPS_MASTERDIR/$f ] && mkdir -p $XBPS_MASTERDIR/$f
	done

	# Copy /etc/passwd and /etc/group from base-files.
	cp -f $XBPS_SRCPKGDIR/base-files/files/passwd $XBPS_MASTERDIR/etc
	echo "$(whoami):x:$(id -u):$(id -g):$(whoami) user:/tmp:/bin/xbps-shell" \
		>> $XBPS_MASTERDIR/etc/passwd
	cp -f $XBPS_SRCPKGDIR/base-files/files/group $XBPS_MASTERDIR/etc
	echo "$(whoami):x:$(id -g):" >> $XBPS_MASTERDIR/etc/group

	# Copy /etc/hosts from base-files.
	cp -f $XBPS_SRCPKGDIR/base-files/files/hosts $XBPS_MASTERDIR/etc

	ln -sfr ${XBPS_MASTERDIR}/bin/bash ${XBPS_MASTERDIR}/bin/sh
	rm -f $XBPS_MASTERDIR/etc/xbps/xbps.conf

	touch $XBPS_MASTERDIR/.xbps_chroot_init
}

chroot_sync_repos() {
	local f=

	if [ ! -f ${XBPS_MASTERDIR}/etc/xbps/xbps.conf ]; then
		install -Dm644 ${XBPS_SHAREDIR}/chroot/xbps.conf \
			${XBPS_MASTERDIR}/etc/xbps/xbps.conf
	fi
	# Make sure to sync index for remote repositories.
	xbps-install -r ${XBPS_MASTERDIR} \
			-C ${XBPS_MASTERDIR}/etc/xbps/xbps.conf -S
	if [ -n "$XBPS_CROSS_BUILD" ]; then
		env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH \
			xbps-install -r $XBPS_MASTERDIR/usr/$XBPS_CROSS_TRIPLET \
				-C ${XBPS_MASTERDIR}/etc/xbps/xbps.conf -S
	fi

	return 0
}

chroot_handler() {
	local _chargs="--mount-bind ${XBPS_DISTDIR} /xbps \
		--mount-bind /dev /dev --mount-bind /sys /sys \
		--mount-proc /proc"

	if [ -n "$XBPS_HOSTDIR" ]; then
		_chargs="${_chargs} --mount-bind $XBPS_HOSTDIR /host"
	fi

	local action="$1" pkg="$2" rv=0 arg=

	[ -z "$action" -a -z "$pkg" ] && return 1

	chroot_prepare || return $?
	chroot_init || return $?
	chroot_sync_repos || return $?

	if [ "$action" = "chroot" ]; then
		$CHROOT_CMD ${_chargs} $XBPS_MASTERDIR /bin/xbps-shell || rv=$?
	else
		[ -n "$XBPS_BUILD_OPTS" ] && arg="$arg -o $XBPS_BUILD_OPTS"
		[ -n "$XBPS_CROSS_BUILD" ] && arg="$arg -a $XBPS_CROSS_BUILD"
		[ -n "$KEEP_WRKSRC" ] && arg="$arg -C"
		[ -n "$KEEP_AUTODEPS" ] && arg="$arg -K"
		[ -n "$NOCOLORS" ] && arg="$arg -L"

		action="$arg $action"
		env IN_CHROOT=1 LANG=C \
			$CHROOT_CMD ${_chargs} $XBPS_MASTERDIR sh -c \
			"xbps-src $action $pkg" || rv=$?
	fi

	msg_normal "Exiting from chroot on $XBPS_MASTERDIR.\n"

	return $rv
}

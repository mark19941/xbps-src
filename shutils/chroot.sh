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

	if [ ! -d $XBPS_MASTERDIR/usr/local/etc/xbps ]; then
		mkdir -p $XBPS_MASTERDIR/usr/local/etc/xbps
	fi

	XBPSSRC_CF=$XBPS_MASTERDIR/usr/local/etc/xbps/xbps-src.conf

	cat > $XBPSSRC_CF <<_EOF
# Generated configuration file by xbps-src, DO NOT EDIT!
XBPS_DISTDIR=/xbps
XBPS_MASTERDIR=/
XBPS_CFLAGS="$XBPS_CFLAGS"
XBPS_CXXFLAGS="$XBPS_CFLAGS"
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
	echo "# End of configuration file." >> $XBPSSRC_CF

	if [ -d $XBPS_MASTERDIR/tmp ]; then
		msg_normal "Cleaning up /tmp...\n"
		[ -h ${XBPS_MASTERDIR}/tmp ] || rm -rf $XBPS_MASTERDIR/tmp/*
	fi

	# Create custom script to start the chroot bash shell.
	cat > $XBPS_MASTERDIR/bin/xbps-shell <<_EOF
#!/bin/sh

XBPS_SRC_VERSION="$XBPS_SRC_VERSION"

. /usr/local/etc/xbps/xbps-src.conf
. /usr/local/share/xbps-src/shutils/init_funcs.sh

export XBPS_ETCDIR=/usr/local/etc/xbps
export XBPS_SHAREDIR=/usr/local/share/xbps-src
export XBPS_LIBEXECDIR=/usr/local/libexec/xbps-src

set_defvars

PATH=/usr/local/sbin:/usr/lib/perl5/core_perl/bin:/usr/bin:/usr/sbin

exec env -i PATH="\$PATH" XBPS_ETCDIR="\$XBPS_ETCDIR" \
	XBPS_SHAREDIR="\$XBPS_SHAREDIR" XBPS_LIBEXECDIR="\$XBPS_LIBEXECDIR" \
	XBPS_INSTALL_CMD="\$XBPS_INSTALL_CMD" \
	XBPS_RECONFIGURE_CMD="\$XBPS_RECONFIGURE_CMD" \
	XBPS_REMOVE_CMD="\$XBPS_REMOVE_CMD" \
	XBPS_QUERY_CMD="\$XBPS_QUERY_CMD" \
	XBPS_UHELPER_CMD="\$XBPS_UHELPER_CMD" XBPS_FETCH_CMD="\$XBPS_FETCH_CMD" \
	XBPS_CMPVER_CMD="\$XBPS_CMPVER_CMD" XBPS_DIGEST_CMD="\$XBPS_DIGEST_CMD" \
	IN_CHROOT=1 LANG=C PS1="[\u@$XBPS_MASTERDIR \W]$ " /bin/bash +h

_EOF
	chmod 755 $XBPS_MASTERDIR/bin/xbps-shell
}

prepare_chroot() {
	local f=

	if [ ! -f $XBPS_MASTERDIR/bin/bash ]; then
		msg_error "Bootstrap not installed in $XBPS_MASTERDIR, can't continue.\n"
	fi

	# Create some required files.
	cp -f /etc/resolv.conf $XBPS_MASTERDIR/etc
	cp -f /etc/services $XBPS_MASTERDIR/etc
	[ -f /etc/localtime ] && cp -f /etc/localtime $XBPS_MASTERDIR/etc

	for f in run/utmp log/btmp log/lastlog log/wtmp; do
		touch -f $XBPS_MASTERDIR/var/$f
	done
	for f in run/utmp log/lastlog; do
		chmod 644 $XBPS_MASTERDIR/var/$f
	done
	[ ! -d $XBPS_MASTERDIR/boot ] && mkdir -p $XBPS_MASTERDIR/boot

	cat > $XBPS_MASTERDIR/etc/passwd <<_EOF
root:x:0:0:root:/root:/bin/bash
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
$(whoami):x:$(id -u):$(id -g):$(whoami) user:/tmp:/bin/xbps-shell
_EOF

	# Default group list as specified by LFS.
	cat > $XBPS_MASTERDIR/etc/group <<_EOF
root:x:0:
bin:x:1:
sys:x:2:
kmem:x:3:
wheel:x:4:
tty:x:5:
tape:x:6:
daemon:x:7:
floppy:x:8:
disk:x:9:
lp:x:10:
dialout:x:11:
audio:x:12:
video:x:13:
utmp:x:14:
usb:x:15:
cdrom:x:16:
optical:x:17:
mail:x:18:
storage:x:19:
scanner:x:20:
nogroup:x:99:
users:x:1000:
$(whoami):x:$(id -g):
_EOF

	# Default file as in Ubuntu.
	cat > $XBPS_MASTERDIR/etc/hosts <<_EOF
127.0.0.1	xbps	localhost.localdomain	localhost
127.0.1.1	xbps

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
_EOF

	create_binsh_symlink

	touch $XBPS_MASTERDIR/.xbps_perms_done
}

create_binsh_symlink() {
	ln -sfr ${XBPS_MASTERDIR}/bin/bash ${XBPS_MASTERDIR}/bin/sh
}

prepare_binpkg_repos() {
	local f=

	if [ ! -f ${XBPS_MASTERDIR}/usr/local/etc/xbps/xbps.conf ]; then
		install -Dm644 ${XBPS_SHAREDIR}/chroot/xbps.conf \
			${XBPS_MASTERDIR}/usr/local/etc/xbps/xbps.conf
		# Make sure to sync index for remote repositories.
		xbps-install -r ${XBPS_MASTERDIR} \
			-C ${XBPS_MASTERDIR}/usr/local/etc/xbps/xbps.conf \
			-y foo >/dev/null 2>&1
	fi

	return 0
}

install_host_utils() {
	local needed= _cmd=
	local prefix=$XBPS_MASTERDIR/usr/local

	if [ ! -f ${XBPS_MASTERDIR}/.xbps_shared_utils_done ]; then
		msg_normal "Installing required host utils on masterdir...\n"

		# Add required xbps utils.
		mkdir -p $prefix/lib $prefix/sbin
		for f in install rindex reconfigure remove \
			query uhelper create; do
			_cmd=$(which xbps-${f} 2>/dev/null)
			_xcmd=$(basename ${_cmd})
			if [ -z "${_cmd}" ]; then
				msg_error "Unexistent ${_cmd} file!"
				exit 1
			fi
			install -Dm755 ${_cmd} $prefix/sbin/${_xcmd}.real
			# copy required shlibs
			for j in $(ldd ${_cmd}|awk '{print $3}'); do
				install -m755 $j $prefix/lib
			done
			# Create wrapper for cmd
			echo "#!/bin/sh" > $prefix/sbin/${_xcmd}
			echo "export PATH=/usr/local/sbin:\$PATH" >> \
				$prefix/sbin/${_xcmd}
			echo "export LD_LIBRARY_PATH=/usr/local/lib" >> \
				$prefix/sbin/${_xcmd}
			echo "${_xcmd}.real \"\$@\"" >> $prefix/sbin/${_xcmd}
			echo "exit \$?" >> $prefix/sbin/${_xcmd}
			chmod 755 $prefix/sbin/${_xcmd}
		done

		# Add required git utils.
		for f in git git-ls-files git-rev-list git-branch; do
			if [ -f /usr/libexec/git-core/$f ]; then
				_cmd=/usr/libexec/git-core/$f
			elif [ -f /usr/lib/git-core/$f ]; then
				_cmd=/usr/lib/git-core/$f
			elif [ -f /usr/bin/$f ]; then
				_cmd=/usr/bin/$f
			else
				msg_error "cannot find git-$f binary!\n"
			fi
			_xcmd=$(basename ${_cmd})
			install -Dm755 ${_cmd} $prefix/sbin/${_xcmd}.real
			# copy required shlibs
			for j in $(ldd ${_cmd}|awk '{print $3}'); do
				install -m755 $j $prefix/lib
			done
			# Create wrapper for cmd
			echo "#!/bin/sh" > $prefix/sbin/${_xcmd}
			echo "export PATH=/usr/local/sbin:\$PATH" >> \
				$prefix/sbin/${_xcmd}
			echo "export LD_LIBRARY_PATH=/usr/local/lib" >> \
				$prefix/sbin/${_xcmd}
			echo "${_xcmd}.real \"\$@\"" >> $prefix/sbin/${_xcmd}
			echo "exit \$?" >> $prefix/sbin/${_xcmd}
			chmod 755 $prefix/sbin/${_xcmd}
		done

		touch ${XBPS_MASTERDIR}/.xbps_shared_utils_done
	fi
}

install_xbps_src() {
	set -e
	install -Dm755 ${XBPS_SBINDIR}/xbps-src \
		${XBPS_MASTERDIR}/usr/local/sbin/xbps-src
	install -Dm755 ${XBPS_LIBEXECDIR}/xbps-src-doinst-helper \
		${XBPS_MASTERDIR}/usr/local/libexec/xbps-src-doinst-helper
	install -d ${XBPS_MASTERDIR}/usr/local/share/xbps-src/shutils
	install -m644 ${XBPS_SHAREDIR}/shutils/*.sh \
		${XBPS_MASTERDIR}/usr/local/share/xbps-src/shutils
	install -d ${XBPS_MASTERDIR}/usr/local/share/xbps-src/helpers
	install -m644 ${XBPS_SHAREDIR}/helpers/*.sh \
		${XBPS_MASTERDIR}/usr/local/share/xbps-src/helpers
	set +e
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

	for f in dev sys proc xbps host; do
		[ ! -d $XBPS_MASTERDIR/$f ] && mkdir -p $XBPS_MASTERDIR/$f
	done

	chroot_init || return $?
	create_binsh_symlink || return $?
	install_host_utils || return $?
	install_xbps_src || return $?
	prepare_binpkg_repos || return $?

	if [ "$action" = "chroot" ]; then
		$CHROOT_CMD ${_chargs} $XBPS_MASTERDIR /bin/xbps-shell || rv=$?
	else
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

# Environment exported for use in packages.

if [ "$build_style" = "gnu-configure" -o -z "$build_style" ]; then
	confargs="--prefix=/usr --sysconfdir=/etc --infodir=/usr/share/info
		--mandir=/usr/share/man --localstatedir=/var "

	if [ "$CROSS_BUILD" ]; then
		confargs+=" --host=$XBPS_CROSS_TRIPLET
			--with-sysroot=$XBPS_CROSS_BASE
			--with-libtool-sysroot=$XBPS_CROSS_BASE "
	fi

	export configure_args="${confargs} ${configure_args}"
fi

if [ "$CROSS_BUILD" ]; then
	export PKG_CONFIG_SYSROOT_DIR="$XBPS_CROSS_BASE"
	export PKG_CONFIG_PATH="$XBPS_CROSS_BASE/lib/pkgconfig:$XBPS_CROSS_BASE/usr/share/pkgconfig"
	export PKG_CONFIG_LIBDIR="$XBPS_CROSS_BASE/lib/pkgconfig"
fi

if [ -z "$CHROOT_READY" ]; then
	export PKG_CONFIG_PATH="${XBPS_MASTERDIR}/usr/lib/pkgconfig:${XBPS_MASTERDIR}/usr/share/pkgconfig"
fi

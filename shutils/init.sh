# -*-* shell *-*-

set_cross_defvars() {
	local CROSSVARS= i= val=

	[ -z "$XBPS_CROSS_BUILD" ] && return 0

	if [ ! -r ${XBPS_CROSSPFDIR}/${XBPS_CROSS_BUILD}.sh ]; then
		echo "ERROR: missing cross build profile for ${XBPS_CROSS_BUILD}, exiting."
		exit 1
	fi

	. ${XBPS_CROSSPFDIR}/${XBPS_CROSS_BUILD}.sh

	if [ -z "$CHROOT_READY" ]; then
		echo "ERROR: chroot mode not activated (install a bootstrap)."
		exit 1
	elif [ -z "$IN_CHROOT" ]; then
		return 0
	fi

	# Install required pkgs for cross building.
	if [ "$XBPS_TARGET" != "remove-autodeps" ]; then
		check_installed_pkg cross-${XBPS_CROSS_TRIPLET}-0.1_1
		if [ $? -ne 0 ]; then
			echo "Installing required cross pkg: cross-${XBPS_CROSS_TRIPLET}"
			$XBPS_INSTALL_CMD -Ay cross-${XBPS_CROSS_TRIPLET} 2>&1 >/dev/null
			if [ $? -ne 0 ]; then
				echo "ERROR: failed to install cross-${XBPS_CROSS_TRIPLET}"
				exit 1
			fi
		fi
		$XBPS_INSTALL_CMD -r /usr/${XBPS_CROSS_TRIPLET} \
			-Sy cross-vpkg-dummy 2>&1 >/dev/null
		if [ $? -ne 0 -a $? -ne 6 ]; then
			echo "ERROR: failed to install cross-vpkg-dummy"
			exit 1
		fi
	fi

	CROSSVARS="TARGET_ARCH CROSS_TRIPLET CROSS_CFLAGS CROSS_CXXFLAGS"
	for i in ${CROSSVARS}; do
		eval val="\$XBPS_$i"
		if [ -z "$val" ]; then
			echo "ERROR: XBPS_$i is not defined!"
			exit 1
		fi
	done

	XBPS_UHELPER_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH xbps-uhelper -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_INSTALL_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_INSTALL_CMD -c /host/repocache -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_QUERY_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_QUERY_CMD -c /host/repocache -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_RINDEX_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_RINDEX_CMD"
	XBPS_RECONFIGURE_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_RECONFIGURE_CMD -r /usr/${XBPS_CROSS_TRIPLET}"
	XBPS_REMOVE_XCMD="env XBPS_TARGET_ARCH=$XBPS_TARGET_ARCH $XBPS_REMOVE_CMD -r /usr/${XBPS_CROSS_TRIPLET}"

	export XBPS_CROSS_TRIPLET XBPS_CROSS_CFLAGS XBPS_CROSS_CXXFLAGS
	export XBPS_UHELPER_XCMD XBPS_INSTALL_XCMD XBPS_QUERY_XCMD
	export XBPS_RINDEX_XCMD XBPS_RECONFIGURE_XCMD XBPS_REMOVE_XCMD
	export XBPS_TARGET_MACHINE=$XBPS_TARGET_ARCH
	export XBPS_CROSS_BASE=/usr/$XBPS_CROSS_TRIPLET
	export XBPS_CROSS_TRIPLET
}

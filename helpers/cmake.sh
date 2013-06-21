#
# This helper is for templates using cmake.
#

do_configure() {
	[ ! -d build ] && mkdir build
	cd build

	if [ "$CROSS_BUILD" ]; then
		cat > cross_${XBPS_CROSS_TRIPLET}.cmake <<_EOF
SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_VERSION 1)

SET(CMAKE_C_COMPILER   ${XBPS_CROSS_TRIPLET}-gcc)
SET(CMAKE_CXX_COMPILER ${XBPS_CROSS_TRIPLET}-g++)

SET(CMAKE_FIND_ROOT_PATH  ${XBPS_CROSS_BASE})

SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
_EOF
		configure_args+="-DCMAKE_TOOLCHAIN_FILE=cross_${XBPS_CROSS_TRIPLET}.cmake"
	fi
	cmake -DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_SKIP_RPATH=ON \
		${configure_args} ..
}

do_build() {
	if [ -z "$make_cmd" ]; then
		make_cmd=make
	fi
	cd build
	${make_cmd} ${makejobs} ${make_build_args} ${make_build_target}
}

do_install() {
	local target

	if [ -z "$make_install_target" ]; then
		target="DESTDIR=${DESTDIR} install"
	else
		target="${make_install_target}"
	fi
	if [ -z "$make_cmd" ]; then
		make_cmd=make
	fi
	cd build
	${make_cmd} ${make_install_args} ${target}
}

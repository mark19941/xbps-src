#
# This helper is for templates using cmake.
#
do_configure() {
	[ ! -d build ] && mkdir build
	cd build
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

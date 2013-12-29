#
# This helper is for templates using GNU Makefiles.
#
do_build() {
	if [ -z "$make_cmd" ]; then
		make_cmd=make
	fi
	${make_cmd} ${makejobs} ${make_build_args} ${make_build_target}
}

do_install() {
	make_install_args+=" PREFIX=/usr DESTDIR=${DESTDIR}"

	if [ -z "$make_install_target" ]; then
		make_install_target="install"
	fi
	if [ -z "$make_cmd" ]; then
		make_cmd=make
	fi
	${make_cmd} ${make_install_args} ${make_install_target}
}

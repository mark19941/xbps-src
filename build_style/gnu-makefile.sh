#
# This helper is for templates using GNU Makefiles.
#
do_build() {
	: ${make_cmd:=make}

	${make_cmd} ${makejobs} ${make_build_args} ${make_build_target}
}

do_install() {
	: ${make_cmd:=make}
	: ${make_install_target:=install}

	make_install_args+=" PREFIX=/usr DESTDIR=${DESTDIR}"

	${make_cmd} CC="$CC" LD="$LD" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
		AR="$AR" RANLIB="$RANLIB" STRIP="$STRIP" \
		${make_install_args} ${make_install_target}
}

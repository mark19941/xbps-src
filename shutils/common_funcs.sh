# -*-* shell *-*-
#
# Common functions for xbps.
#

run_func() {
	local func="$1" logpipe= logfile= teepid=

	logpipe=/tmp/xbps_src_logpipe.$$
	if [ -d "${wrksrc}" ]; then
		logfile=${wrksrc}/.xbps_${func}.log
	else
		logfile=$(mktemp -t xbps_${func}_${pkgname}.log.XXXXXXXX)
	fi

	msg_normal "$pkgver: running $func ...\n"

	set -E
	trap 'error_func $func $LINENO' ERR

	mkfifo "$logpipe"
	tee "$logfile" < "$logpipe" &
	teepid=$!

	$func &>"$logpipe"

	wait $teepid
	rm "$logpipe"

	set +E
}

error_func() {
	remove_pkgdestdir_sighandler ${pkgname} $KEEP_AUTODEPS
	if [ -n "$1" -a -n "$2" ]; then
		msg_red "$pkgver: failed to run $1() at line $2.\n"
	fi
	exit 2
}

remove_pkgdestdir_sighandler() {
	local subpkg= _pkgname="$1" _kwrksrc="$2"

	setup_tmpl ${_pkgname}
	[ -z "$sourcepkg" ] && return 0

	# If there is any problem in the middle of writting the metadata,
	# just remove all files from destdir of pkg.

	for subpkg in ${subpackages}; do
		if [ -d "$XBPS_DESTDIR/${subpkg}-${version%_*}" ]; then
			rm -rf "$XBPS_DESTDIR/${subpkg}-${version%_*}"
		fi
		if [ -f ${wrksrc}/.xbps_do_install_${subpkg}_done ]; then
			rm -f ${wrksrc}/.xbps_do_install_${subpkg}_done
		fi
	done

	if [ -d "$XBPS_DESTDIR/${sourcepkg}-${version%_*}" ]; then
		rm -rf "$XBPS_DESTDIR/${sourcepkg}-${version%_*}"
	fi
	if [ -f ${wrksrc}/.xbps_install_done ]; then
		rm -f ${wrksrc}/.xbps_install_done
	fi
	[ -z "${_kwrksrc}" ] && remove_pkg_autodeps
}

msg_red() {
	# error messages in bold/red
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	if [ -n "$IN_CHROOT" ]; then
		printf >&2 "[chroot] => ERROR: $@"
	else
		printf >&2 "=> ERROR: $@"
	fi
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_red_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	printf >&2 "$@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_error() {
	msg_red "$@"
	exit 1
}

msg_error_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	printf >&2 "=> ERROR: $@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
	exit 1
}

msg_warn() {
	# warn messages in bold/yellow
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
	if [ -n "$IN_CHROOT" ]; then
		printf >&2 "[chroot] => WARNING: $@"
	else
		printf >&2 "=> WARNING: $@"
	fi
	[ -n "$NOCOLORS" ] || printf >&2  "\033[m"
}

msg_warn_nochroot() {
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
	printf >&2 "=> WARNING: $@"
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_normal() {
	# normal messages in bold
	[ -n "$NOCOLORS" ] || printf "\033[1m"
	if [ -n "$IN_CHROOT" ]; then
		printf "[chroot] => $@"
	else
		printf "=> $@"
	fi
	[ -n "$NOCOLORS" ] || printf "\033[m"
}

msg_normal_append() {
	[ -n "$NOCOLORS" ] || printf "\033[1m"
	printf "$@"
	[ -n "$NOCOLORS" ] || printf "\033[m"
}

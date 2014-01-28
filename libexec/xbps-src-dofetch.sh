#!/bin/bash
#
# Passed arguments:
# 	$1 - pkgname [REQUIRED]

verify_sha256_cksum() {
	local file="$1" origsum="$2" distfile="$3"

	[ -z "$file" -o -z "$cksum" ] && return 1

	msg_normal "$pkgver: verifying checksum for distfile '$file'... "
	filesum=$(${XBPS_DIGEST_CMD} $distfile)
	if [ "$origsum" != "$filesum" ]; then
		echo
		msg_red "SHA256 mismatch for '$file:'\n$filesum\n"
		return 1
	else
		msg_normal_append "OK.\n"
	fi
}

if [ $# -ne 1 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname"
	exit 1
fi

PKGNAME="$1"

. $XBPS_SHUTILSDIR/common.sh

setup_pkg "$PKGNAME"

for f in $XBPS_COMMONDIR/environment/*.sh; do
	. $f
done

if [ -z $pkgname ]; then
	exit 1
fi
#
# There's nothing of interest if we are a meta template.
#
XBPS_FETCH_DONE="$wrksrc/.xbps_fetch_done"

if [ -f "$XBPS_FETCH_DONE" ]; then
	exit 0
fi

#
# if a pkg defines a do_fetch() function, use it.
#
if declare -f do_fetch >/dev/null; then
	cd ${XBPS_BUILDDIR}
	[ -n "$build_wrksrc" ] && mkdir -p "$wrksrc"
	run_func do_fetch
	touch -f $XBPS_FETCH_DONE
	exit 0
fi

if [ -n "$create_srcdir" ]; then
	srcdir="$XBPS_SRCDISTDIR/$pkgname-$version"
else
	srcdir="$XBPS_SRCDISTDIR"
fi
[ ! -d "$srcdir" ] && mkdir -p -m775 "$srcdir" && chgrp xbuilder "$srcdir"

cd $srcdir || msg_error "$pkgver: cannot change dir to $srcdir!\n"
for f in ${distfiles}; do
	curfile=$(basename $f)
	distfile="$srcdir/$curfile"
	while true; do
		flock -w 1 ${distfile}.part true
		if [ $? -eq 0 ]; then
			break
		fi
		msg_warn "$pkgver: ${distfile} is being already downloaded, waiting for 1s ...\n"
	done
	if [ -f "$distfile" ]; then
		flock -n ${distfile}.part rm -f ${distfile}.part
		for i in ${checksum}; do
			if [ $dfcount -eq $ckcount -a -n "$i" ]; then
				cksum=$i
				found=yes
				break
			fi

			ckcount=$(($ckcount + 1))
		done

		if [ -z $found ]; then
			msg_error "$pkgver: cannot find checksum for $curfile.\n"
		fi

		verify_sha256_cksum $curfile $cksum $distfile
		rval=$?
		unset cksum found
		ckcount=0
		dfcount=$(($dfcount + 1))
		continue
	fi

	msg_normal "$pkgver: fetching distfile '$curfile'...\n"

	if [ -n "$distfiles" ]; then
		localurl="$f"
	else
		localurl="$url/$curfile"
	fi

	flock ${distfile}.part $XBPS_FETCH_CMD $localurl
	if [ $? -ne 0 ]; then
		unset localurl
		if [ ! -f $distfile ]; then
			msg_error "$pkgver: couldn't fetch $curfile.\n"
		else
			msg_error "$pkgver: there was an error fetching $curfile.\n"
		fi
	else
		unset localurl
		#
		# XXX duplicate code.
		#
		for i in ${checksum}; do
			if [ $dfcount -eq $ckcount -a -n "$i" ]; then
				cksum=$i
				found=yes
				break
			fi

			ckcount=$(($ckcount + 1))
		done

		if [ -z $found ]; then
			msg_error "$pkgver: cannot find checksum for $curfile.\n"
		fi

		verify_sha256_cksum $curfile $cksum $distfile
		rval=$?
		unset cksum found
		ckcount=0
	fi

	dfcount=$(($dfcount + 1))
done

exit $rval

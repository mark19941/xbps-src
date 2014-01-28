#!/bin/bash
#
# Passed arguments:
#	$1 - pkgname [REQUIRED]

_process_patch() {
	local _args= _patch= i=$1

	_args="-Np0"
	_patch=$(basename $i)
	if [ -f $PATCHESDIR/${_patch}.args ]; then
		_args=$(cat $PATCHESDIR/${_patch}.args)
	elif [ -n "$patch_args" ]; then
		_args=$patch_args
	fi
	cp -f $i $wrksrc

	# Try to guess if its a compressed patch.
	if $(echo $i|grep -q '.diff.gz'); then
		gunzip $wrksrc/${_patch}
		_patch=${_patch%%.gz}
	elif $(echo $i|grep -q '.patch.gz'); then
		gunzip $wrksrc/${_patch}
		_patch=${_patch%%.gz}
	elif $(echo $i|grep -q '.diff.bz2'); then
		bunzip2 $wrksrc/${_patch}
		_patch=${_patch%%.bz2}
	elif $(echo $i|grep -q '.patch.bz2'); then
		bunzip2 $wrksrc/${_patch}
		_patch=${_patch%%.bz2}
	elif $(echo $i|grep -q '.diff'); then
		:
	elif $(echo $i|grep -q '.patch'); then
		:
	else
		msg_warn "$pkgver: unknown patch type: $i.\n"
		continue
	fi

	cd $wrksrc && patch -sl ${_args} -i ${_patch} 2>/dev/null
	if [ $? -eq 0 ]; then
		msg_normal "$pkgver: patch applied: ${_patch}.\n"
	else
		msg_error "'$pkgver: couldn't apply patch: ${_patch}.\n"
	fi
}

if [ $# -ne 1 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname"
	exit 1
fi

PKGNAME="$1"

. $XBPS_SHUTILSDIR/common.sh

for f in $XBPS_COMMONDIR/helpers/*.sh; do
	. $f
done

setup_pkg "$PKGNAME"

for f in $XBPS_COMMONDIR/environment/*.sh; do
	. $f
done

XBPS_APPLYPATCHES_DONE="$wrksrc/.xbps_applypatches_done"

if [ -f $XBPS_APPLYPATCHES_DONE ]; then
	exit 0
fi
if [ ! -d $PATCHESDIR ]; then
	exit 0
fi

if [ -r $PATCHESDIR/series ]; then
	cat $PATCHESDIR/series | while read f; do
		_process_patch "$PATCHESDIR/$f"
	done
else
	for f in $PATCHESDIR/*; do
		[ ! -f $f ] && continue
		if $(echo $f|grep -Eq '^.*.args$'); then
			continue
		fi
		_process_patch $f
	done
fi

touch -f $XBPS_APPLYPATCHES_DONE

exit 0

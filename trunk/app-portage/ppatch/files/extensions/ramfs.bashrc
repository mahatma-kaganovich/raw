#### RAMTMPDIR="<enable_temp=yes|no> <max_dist_size> <ramfs_size>"
#### example: RAMTMPDIR="no 5M 1000M" - always ramfs if dist < 50000000
#### example: RAMTMPDIR="yes 5M 1000M" - same, but else - mount $TMPDIR & $D
#### ramfs_size may be omitted, but some of distros need to check free space

_ramtmpdir(){
	local s=0 i c=`pwd` m="${2^^}" o="none -t ramfs -o noatime"
	m="${m//G/000M}"
	m="${m//M/000K}"
	m="${m//K/000}"
	[ "$3" = '' ] || o+=",size=$3"
	for i in "$DISTDIR"/*; do
		[ -e "$i" ] && s=$[s+$(stat "`readlink -f "$i"`" --format='%s')]
	done
	if [ "$m" = '' ] || [ "$s" = 0 -a "$m" != 0 ] || [ "$s" -ge "$m" ]; then
		echo ">>> Size=$s > $2"
		[ "$1" = yes ] && {
			echo ">>> Mounting ramfs to temp"
			mount $o "$TMPDIR"
			# workaround for install+strip hardlink
			# attr??
#			i="$TMPDIR/...image"
#			mkdir "$i"  && ln -sf "$i" "${D%/}"
		}
		return
	fi
	rm "$PORTAGE_BUILDDIR.tmp" -Rf
	rename "${PORTAGE_BUILDDIR##*/}" "${PORTAGE_BUILDDIR##*/}.tmp" "$PORTAGE_BUILDDIR" &&
	    mkdir "$PORTAGE_BUILDDIR" &&
	    mount $o "$PORTAGE_BUILDDIR" && {
		chown portage:portage "$PORTAGE_BUILDDIR"
		mv "$PORTAGE_BUILDDIR".tmp/* "$PORTAGE_BUILDDIR/"
		echo ">>> Mounting ramfs" # this place 4 compress-build-log
		for i in "$PORTAGE_BUILDDIR".tmp/.*; do ln -s "$i" "$PORTAGE_BUILDDIR/${i##*/}"; done 2>/dev/null
		cd "$c"
	}
}

[ "${RAMTMPDIR:-no}" != no -a -n "$TMPDIR" -a -n "$PORTAGE_BUILDDIR" -a -z "${TMPDIR##$PORTAGE_BUILDDIR/*}" ] && case "$EBUILD_PHASE" in
clean)
	umount -l "$PORTAGE_BUILDDIR" 2>/dev/null &&
	rm "$PORTAGE_BUILDDIR.tmp" -Rf ||
	umount -l "$TMPDIR"
;;
setup)
	_ramtmpdir $RAMTMPDIR
;;
esac

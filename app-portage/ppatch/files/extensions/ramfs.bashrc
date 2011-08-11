[ "$RAMTMPDIR" = yes -a -n "$TMPDIR" ] && case "$EBUILD_PHASE" in
clean)
	umount -l "$TMPDIR"
;;
setup)
	mount -t ramfs -o noatime none "$TMPDIR"
;;
esac

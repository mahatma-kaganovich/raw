[ "$RAMTMPDIR" = yes -a -n "$TMPDIR" -a -n "$PORTAGE_BUILDDIR" -a -z "${TMPDIR##$PORTAGE_BUILDDIR/*}" ] && case "$EBUILD_PHASE" in
clean)
	umount -l "$TMPDIR"
;;
setup)
	mount -t ramfs -o noatime none "$TMPDIR"
;;
esac

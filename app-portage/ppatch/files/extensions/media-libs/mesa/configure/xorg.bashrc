[[ "$IUSE" == *gallium* ]] &&
if use gallium; then
	grep -sq enable_xorg "$S"/configure* &&
	[ -n "${IUSE##*xorg*}" ] && export enable_xorg=yes && ewarn "Use -gallium first time if build breaks via circullar Xorg dependence"
fi

if use gallium; then
	[ -n "${IUSE##*xorg*}" ] && export enable_xorg=yes && ewarn "Use -gallium first time if build breaks via circullar Xorg dependence"
	sed -i -e 's:modesetting:modesettin2:g' "$S/src/gallium/targets/xorg-i915"/*
	([ -n "${IUSE##*xorg*}" ] || use xorg) &&
		(use video_cards_intel || use video_cards_i915) &&
		ewarn "i915 state tracker driver renamed from 'modesetting' to 'modesettin2' to compatibility with x86-video-modesetting"
fi

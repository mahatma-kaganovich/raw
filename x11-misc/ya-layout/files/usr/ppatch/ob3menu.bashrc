[ "$EBUILD_PHASE" = postinst ] && [ -e "$D"/usr/share/applications -o -e "$D"/usr/share/desktop-directories ] && {
	echo '<openbox_pipe_menu>'
	/usr/bin/ob3menu
	echo '</openbox_pipe_menu>'
} >/var/lib/ya/menu.xml

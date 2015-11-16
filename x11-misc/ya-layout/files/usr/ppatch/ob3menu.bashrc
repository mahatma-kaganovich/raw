[ "$EBUILD_PHASE" = postinst ] && [ -e "$D"/usr/share/applications -o -e "$D"/usr/share/desktop-directories ] && {
	echo '<openbox_menu><menu id="root-menu" label="Openbox 3">'
	/usr/bin/ob3menu
	echo '</menu></openbox_menu>'
} >/var/lib/ya/menu.xml

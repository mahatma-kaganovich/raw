[ "$EBUILD_PHASE" = preinst ] && {
	[ -e "$D"/usr/share/applications -o -e "$D"/usr/share/desktop-directories -o -e "$D"/usr/share/icons -o -e "$D"/usr/share/pixmaps ] && ob3config_preinst=yes
	for i in "$D"//usr/share/pixmaps/*.xpm; do
		i1="${i%.xpm}.png"
		[ -e "$i" -a ! -e "$i1" ] || continue
		convert "$i" "$i1" || feh -m "$i" -O "$i1"
	done
}
[ "$EBUILD_PHASE" = postinst ] && [ "$ob3config_preinst" = yes ] &&
	/usr/bin/ob3menu|sed -e 's:<openbox_pipe_menu>:<openbox_menu><menu id="root-menu" label="Openbox 3">:' -e 's:</openbox_pipe_menu>:</menu></openbox_menu>:' >/var/lib/ya/menu.xml &&
	/usr/bin/ob3menu --low 8x8 16x16 22x22 + HighContrast locolor Adwaita 48x48 --slow|sed -e 's:<openbox_pipe_menu>:<openbox_menu><menu id="root-menu" label="Openbox 3">:' -e 's:</openbox_pipe_menu>:</menu></openbox_menu>:' >/var/lib/ya/menu2.xml

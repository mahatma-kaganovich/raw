[ "$EBUILD_PHASE" = preinst ] && [ -e "$D"/usr/share/applications -o -e "$D"/usr/share/desktop-directories ] && ob3config_preinst=yes
[ "$EBUILD_PHASE" = postinst ] && [ "$ob3config_preinst" = yes ]  &&
	/usr/bin/ob3menu|sed -e 's:<openbox_pipe_menu>:<openbox_menu><menu id="root-menu" label="Openbox 3">:' -e 's:</openbox_pipe_menu>:</menu></openbox_menu>:' >/var/lib/ya/menu.xml

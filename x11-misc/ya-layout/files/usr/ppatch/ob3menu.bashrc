[ "$PHASE" = postinst ] && [ -e "$D"/usr/share/applications -o -e "$D"/usr/share/desktop-directories ] && /usr/bin/ob3menu >/var/lib/ya/menu.xml

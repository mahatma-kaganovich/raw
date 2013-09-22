EAPI=3
SLOT=0
DESCRIPTION="Simple desktop layout"
LICENSE="*"
IUSE="+udev libnotify minimal bluetooth wifi +jpeg +tiff +svg tint2 alsa"
DEPEND="tint2? ( x11-misc/tint2 )
	>=x11-wm/openbox-3.5.0"
RDEPEND=" ${DEPEND}
	udev? ( virtual/udev net-fs/autofs )
	libnotify? ( x11-libs/libnotify )
	bluetooth? (
		net-wireless/bluez[test-programs]
		net-dialup/ppp
		net-misc/bridge-utils
	)
	wifi? ( net-wireless/wireless-tools )
	media-libs/imlib2[png,jpeg?,tiff?]
	media-gfx/feh
	x11-misc/slock
	alsa? ( media-sound/alsa-utils )
	x11-apps/xfontsel
	!minimal? (
		!tint2? ( || (
		x11-misc/pcmanfm
		xfce-base/xfdesktop[thunar]
		gnome-base/nautilus
		x11-misc/spacefm
		) )
		|| ( media-gfx/imagemagick[png,jpeg?,tiff?,svg?] media-gfx/graphicsmagick[imagemagick,png,jpeg?,tiff?,svg?] )
		x11-wm/openbox[imlib,svg?]
	)"
#	x11-apps/setxkbmap x11-apps/xkbcomp x11-apps/xrdb x11-apps/xwininfo x11-apps/xkill
KEYWORDS="~x86 ~amd64"
HOMEPAGE="http://raw.googlecode.com/"

src_install(){
	cp -aT "$FILESDIR" "${D}" || die
	rm -Rf `find "${D}" -name ".*"`
	chown root:root "${D}" -Rf
	chmod 755 "${D}/usr/bin/"* "${D}/usr/share/${PN}"/auto.cifs
	dosym 'cifs/*' /mnt/auto/smb
	if use udev; then
		dosym /mnt/auto/disk /usr/share/${PN}/Desktop/disk
	else
		rm "${D}/etc/udev" -Rf
	fi
	use jpeg || sed -i -e 's:jpg:tiff:g' "${D}"{/usr/bin/ob3menu,/etc/xdg/ya/menu.xml}
	use tiff || sed -i -e 's:tiff:png:g' "${D}"{/usr/bin/ob3menu,/etc/xdg/ya/menu.xml}
	use svg || sed -i -e 's: --svg::g' "${D}"/etc/xdg/ya/menu.xml
	if use tint2; then
		# hate effects & decorations - non-ergonomic for eyes
		# top-right is also faster
		cp /etc/xdg/tint2/tint2rc "${D}"/etc/xdg/ya/tint2rc &&
		for i in 'task_font sans 12' 'panel_position top right horizontal' 'rounded 3' 'wm_menu 1' 'font_shadow 0' 'border_width 0' 'panel_padding 0 0 0' 'taskbar_padding 2 0 2' 'task_padding 0 0' 'panel_size 0 20'; do
			sed -i -e "s:^${i%% *} = .*\$:${i%% *} = ${i#* }:" "${D}"/etc/xdg/ya/tint2rc
		done
		sed -i -e 's%YA_STARTUP:=XF86Desktop%YA_STARTUP:=TINT2%' "${D}"/usr/bin/ya-session
	else
		sed -i -e 's%YA_STARTUP:=TINT2%YA_STARTUP:=XF86Desktop%' "${D}"/usr/bin/ya-session
	fi
	use bluetooth || rm "$D/etc/ppp" -Rf
	use libnotify || sed -i -e 's:^notify=.*$:notify=:' "${D}"/usr/bin/*
	ewarn "Edit /etc/conf.d/autofs: MASTER_MAP_NAME=\"/usr/share/${PN}/auto.master\"
Then do: \"ya-session --layout [user]\" - to copy minimal Desktop/*
and, possible, restart [udev]"
}

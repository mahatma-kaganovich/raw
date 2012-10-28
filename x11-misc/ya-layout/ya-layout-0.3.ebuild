EAPI=3
SLOT=0
DESCRIPTION="Simple desktop layout"
LICENSE="*"
IUSE="+udev libnotify minimal bluetooth wifi +jpeg +tiff tint2"
DEPEND="tint2? ( x11-misc/tint2 )
	>=x11-wm/openbox-3.5.0"
RDEPEND=" ${DEPEND}
	udev? ( sys-fs/udev net-fs/autofs )
	libnotify? ( x11-libs/libnotify )
	bluetooth? (
		net-wireless/bluez[test-programs]
		net-dialup/ppp
		net-misc/bridge-utils
	)
	wifi? ( net-wireless/wireless-tools )
	!minimal? (
		!tint2? ( || (
		x11-misc/pcmanfm
		xfce-base/xfdesktop[thunar]
		gnome-base/nautilus
		x11-misc/spacefm
		) )
		media-libs/imlib2[png,jpeg?,tiff?]
		media-gfx/imagemagick[png,jpeg?,tiff?]
		media-gfx/feh
		x11-wm/openbox[imlib]
	)"
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
	if use tint2; then
		sed -e 's:^\(task_font = sans\) 7$:\1 12:i' \
		-e 's:^panel_position = bottom center horizontal$:panel_position = top right horizontal:' \
		-e 's:^rounded = [0-9]*:rounded = 3:' \
		-e 's:^wm_menu = 0:wm_menu=1:' \
		-e 's:^font_shadow = 1:font_shadow = 0:' \
			</etc/xdg/tint2/tint2rc >"${D}"/etc/xdg/ya/tint2rc
		sed -i -e 's%YA_STARTUP:=XF86Desktop%YA_STARTUP:=TINT2%' "${D}"/usr/bin/ya-session
	fi
	use bluetooth || rm "$D/etc/ppp" -Rf
	use libnotify || sed -i -e 's:^notify=.*$:notify=:' "${D}"/usr/bin/*
	ewarn "Edit /etc/conf.d/autofs: MASTER_MAP_NAME=\"/usr/share/${PN}/auto.master\"
Then do: \"ya-session --layout [user]\" - to copy minimal Desktop/*
and, possible, restart [udev]"
}

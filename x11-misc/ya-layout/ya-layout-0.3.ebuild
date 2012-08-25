EAPI=3
SLOT=0
DESCRIPTION="Simple desktop layout"
LICENSE="*"
IUSE="+udev libnotify minimal"
RDEPEND="udev? ( sys-fs/udev net-fs/autofs )
	libnotify? ( x11-libs/libnotify )
	>=x11-wm/openbox-3.5.0
	!minimal? ( || (
		x11-misc/pcmanfm
		xfce-base/xfdesktop[thunar]
		gnome-base/nautilus
		x11-misc/spacefm
	) )"
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
	use libnotify || sed -i -e 's:^notify=.*$:notify=:' "${D}"/usr/bin/*
	ewarn "Edit /etc/conf.d/autofs: MASTER_MAP_NAME=\"/usr/share/${PN}/auto.master\"
Then do: \"ya-session --layout [user]\" - to copy minimal Desktop/*
and, possible, restart [udev]"
}

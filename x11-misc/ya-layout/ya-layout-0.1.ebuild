EAPI=3
SLOT=0
DESCRIPTION="Simple desktop layout"
LICENSE="*"
IUSE="+udev"
RDEPEND="udev? ( sys-fs/udev net-fs/autofs )
	>=x11-wm/openbox-3.5.0
	|| (
		x11-misc/pcmanfm
		xfce-base/xfdesktop[thunar]
		gnome-base/nautilus
	)"
KEYWORDS="~x86 ~amd64"
HOMEPAGE="http://raw.googlecode.com/"

src_install(){
	cp -aT "$FILESDIR" "${D}" || die
	rm -Rf `find "${D}" -name ".*"`
	chown root:root "${D}" -Rf
	chmod 755 "${D}/usr/bin/"*
	if use udev; then
		dosym /mnt/auto/disk /usr/share/${PN}/Desktop/disk
	else
		rm "${D}/etc/udev" -Rf
	fi
	ewarn "Edit /etc/conf.d/autofs: MASTER_MAP_NAME=\"/usr/share/${PN}/auto.master\"
Then do: \"ya-session --layout [user]\" - to copy minimal Desktop/*
and, possible, restart [udev]"
}

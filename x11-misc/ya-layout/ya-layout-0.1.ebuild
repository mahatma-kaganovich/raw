EAPI=3
SLOT=0
DESCRIPTION="Simple desktop layout"
LICENSE="*"
RDEPEND="net-fs/autofs
	x11-wm/openbox
	|| ( x11-misc/pcmanfm xfce-base/xfdesktop[thunar] )"
KEYWORDS="~x86 ~amd64"
HOMEPAGE="http://raw.googlecode.com/"

src_install(){
	cp -aT "$FILESDIR" "${D}" || die
	rm -Rf `find "${D}" -name ".*" -delete`
	chown root:root "${D}" -Rf
	chmod 755 "${D}/usr/bin/"*
	dosym /mnt/auto/disk /usr/share/${PN}/disk
	ewarn "Edit /etc/conf.d/autofs: MASTER_MAP_NAME=\"/usr/share/${PN}/auto.master\"
Then do: \"ya-session --layout [user]\" - to copy minimal Desktop/*
and, possible, restart [udev]"
}

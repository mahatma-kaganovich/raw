EAPI=2
SLOT=0
DESCRIPTION="Configure kernel, generate PNP initrd or update & compress genkernel's initrd"
KEYWORDS="x86 amd64"
HOMEPAGE="http://raw.googlecode.com/"
RDEPEND="|| ( sys-fs/cramfs sys-apps/util-linux[cramfs] )
	sys-fs/squashfs-tools
	app-misc/pax-utils
	sys-apps/grep[pcre]"
#	|| ( <sys-libs/glibc-2.14 sys-libs/uclibc net-libs/libtirpc[static-libs] )"
S="${FILESDIR}"

src_install(){
	insinto /etc/kernels
	doins kernel.conf genkernel.conf
	dodir /usr/share
	cp -aT "$FILESDIR" "${D}/usr/share/${PN}" || die
	rm -Rf `find "${D}" -name ".*"`
	dobin ${PN}
	dosym ../../bin/${PN} /usr/share/${PN}
	# suddenly
	dosym _SB_.PCCH "/usr/share/$PN/etc/modflags/"'\_SB_.PCCH'
	newinitd "$FILESDIR"/rawboot rawboot
}

pkg_postinst(){
	local c="${FILESDIR}"/../../../eclass/kernel-2.eclass
	[[ -e "$c" ]] && touch "$c"
}

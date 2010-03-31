EAPI=3
SLOT=0
DESCRIPTION="PNP update & compress modules for genkernel initrd"
S="${FILESDIR}"
KEYWORDS="x86 amd64"
RDEPEND="sys-fs/cramfs
	sys-fs/squashfs-tools
	app-misc/pax-utils
	sys-apps/grep[pcre]"

src_install(){
	cd ${S}
	insinto /usr/share/genpnprd
	doins *
	insinto /etc/kernels
	doins kernel.conf
}

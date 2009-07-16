SLOT=0
DESCRIPTION="PNP update & compress modules for genkernel initrd"
S="${FILESDIR}"
KEYWORDS="x86 amd64"
DEPEND="sys-fs/cramfs
	sys-fs/squashfs-tools"

src_install(){
	cd ${S}
	insinto /usr/share/genpnprd
	doins *
	insinto /etc/kernels
	doins kernel.conf
}

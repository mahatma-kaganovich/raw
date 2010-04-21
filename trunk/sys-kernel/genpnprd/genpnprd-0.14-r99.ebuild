EAPI=3
SLOT=0
DESCRIPTION="PNP update & compress modules for genkernel initrd"
KEYWORDS="x86 amd64"
RDEPEND="sys-fs/cramfs
	sys-fs/squashfs-tools
	app-misc/pax-utils
	sys-apps/grep[pcre]"

src_install(){
	cd "${FILESDIR}"
	insinto /etc/kernels
	doins kernel.conf
	insinto /usr/share/genpnprd
	doins *
	for i in etc sbin; do
		insinto /usr/share/genpnprd/$i
		doins $i/*
	done
}

EAPI=2
SLOT=0
DESCRIPTION="Configure kernel, generate PNP initrd or update & compress genkernel's initrd"
KEYWORDS="x86 amd64"
HOMEPAGE="http://raw.googlecode.com/"
RDEPEND="sys-fs/cramfs
	sys-fs/squashfs-tools
	app-misc/pax-utils
	sys-apps/grep[pcre]"

src_install(){
	cd "${FILESDIR}"
	insinto /etc/kernels
	doins kernel.conf
	insinto /usr/share/${PN}
	doins *
	dobin ${PN}
	dosym ../../bin/${PN} /usr/share/${PN}
	for i in etc sbin; do
		insinto /usr/share/${PN}/$i
		doins $i/*
	done
}

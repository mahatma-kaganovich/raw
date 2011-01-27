EAPI=2
SLOT=0
DESCRIPTION="Configure kernel, generate PNP initrd or update & compress genkernel's initrd"
KEYWORDS="x86 amd64"
HOMEPAGE="http://raw.googlecode.com/"
RDEPEND="|| ( sys-fs/cramfs sys-apps/util-linux[cramfs] )
	sys-fs/squashfs-tools
	app-misc/pax-utils
	sys-apps/grep[pcre]"
S="${FILESDIR}"

src_install(){
	insinto /etc/kernels
	doins kernel.conf
	for i in $(find|sort|grep -v "/\.\|^\.$" ); do
		i="${i#.}"
		if [[ -d ".$i" ]]; then
			dodir "/usr/share/$PN$i"
		else
			insinto "/usr/share/${PN}${i%/*}"
			doins "${i#/}"
		fi
	done
	dobin ${PN}
	dosym ../../bin/${PN} /usr/share/${PN}
}

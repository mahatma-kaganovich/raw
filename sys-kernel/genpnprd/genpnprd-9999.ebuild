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
#	cd "${S}"
	insinto /etc/kernels
	doins kernel.conf
	insinto /usr/share/${PN}
	for i in $(find|sort); do
		i="${i#.}"
		[[ "$i" != */.* ]] && [[ -n "$i" ]] && if [[ -d ".$i" ]]; then
			dodir "/usr/share/$PN$i"
		else
			insinto "/usr/share/${PN}${i%/*}"
			doins "${i#/}" || einfo " - $i"
		fi
	done
	dobin ${PN}
	dosym ../../bin/${PN} /usr/share/${PN}
}

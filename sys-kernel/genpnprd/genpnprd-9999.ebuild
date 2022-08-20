# Copyright 1999-2018 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6
SLOT=0
DESCRIPTION="Configure kernel, generate PNP initrd or update & compress genkernel's initrd"
KEYWORDS="x86 amd64"
HOMEPAGE="https://github.com/mahatma-kaganovich/raw"
RDEPEND="|| ( sys-fs/cramfs sys-apps/util-linux[cramfs] )
	sys-fs/squashfs-tools
	app-misc/pax-utils
	sys-apps/grep[pcre]"
#	|| ( <sys-libs/glibc-2.14 sys-libs/uclibc net-libs/libtirpc[static-libs] )"
S="${FILESDIR}"

src_install(){
	dodir /usr/share
	cp -aT "$(readlink -f $FILESDIR)" "${D}/usr/share/${PN}" || die
	insinto /etc/kernels
	for i in "${D}/usr/share/${PN}"/*.etc; do
		doins "$i"
		unlink "$i"
	done
	rename .etc '' "$D"/etc/kernels/*
	rm -Rf `find "${D}" -name ".*"`
	dobin ${PN}
	dosym ../../bin/${PN} /usr/share/${PN}/${PN}
	# suddenly
	dosym _SB_.PCCH "/usr/share/$PN/etc/modflags/"'\_SB_.PCCH'
}

#pkg_postinst(){
#	local c="${FILESDIR}"/../../../eclass/kernel-2.eclass
#	[[ -e "$c" ]] && touch "$c"
#}

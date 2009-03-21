
inherit eutils

DESCRIPTION="Asyncronous patchshield for Gentoo"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 mips ppc ppc64 s390 sh sparc x86"
RDEPEND="dev-lang/perl"
DEPEND="${RDEPEND}"
PDEPEND="sys-apps/portage"
IUSE="extensions"

pp(){
	local p=$1
	local d
	shift
	for d in $*; do
		dodir ${d}
		insinto ${d}
		doins ${p}/*
	done
}

src_install(){
    local d
    dodir /usr/sbin
    dodir /usr/ppatch
    cp ${FILESDIR}/p-patch-${PV} ${TMPDIR}/p-patch
    cp ${FILESDIR}/*.p-patch ${D}/usr/ppatch/
    if use extensions; then
		pp ${FILESDIR}/sys-kernel /usr/ppatch/sys-kernel/{gentoo,cell,sk,git,hardened,hppa,mips,openvz,rsback,sh,sparc,suspend,usermode,vanilla,vserver,xbox,xen}-sources/compile
    fi
    install ${TMPDIR}/p-patch ${D}/usr/sbin
}

pkg_postinst(){
    SS="${PORTAGE_CONFIGROOT}" p-patch ${FILESDIR}/bashrc.p-patch
}

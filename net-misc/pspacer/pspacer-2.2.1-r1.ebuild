
ESVN_REPO_URI="http://pspacer.googlecode.com/svn/branches/devel/"
inherit eutils subversion

MY_PV=cvs
DESCRIPTION="PSPacer is a precise software pacer of IP traffic for Linux"
#HOMEPAGE="http://www.gridmpi.org/gridtcp.en.jsp"
HOMEPAGE="http://code.google.com/p/ticpp/"
SRC_URI=""
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~*"
IUSE="debug doc"
DEPEND="doc? ( app-text/asciidoc )
	app-portage/ppatch"
PDEPEND="sys-apps/iproute2
	virtual/linux-sources"
#	=dev-libs/libnl-1.0_pre6-r1

src_compile(){
m=""
cf="--without-iproute2 --without-libnl"
use debug && cf="${cf} --enable-debug"
use doc && m="${m} doc"
test ${m} && econf ${cf} && emake ${m}
}

src_install(){
cd ${FILESDIR}
tar -xjf psp-pp-2.1.tar.bz2 -C ${D}
test -d root && cd root && cp -at ${D} * --parents
cd ${S}
#use doc && einstall DESTDIR=${D} docs-install
use doc && cd doc && dodoc * && cp -at ${D}usr/share/doc/${PF}/${DOCDESTTREE} fig/* --parents
p="/usr/ppatch/dev-libs/libnl/compile/"
mkdir ${D}${p} --parents
cp ${S}/patch/* ${D}${p} -Rf
tar -cjf ${D}/usr/ppatch/sys-apps/iproute2/compile/psp.tar.bz2 kernel/sch_psp.h tc/q_psp.c man/man8/tc-psp.8
tar -cjf ${D}/usr/ppatch/sys-kernel/psp.tar.bz2 kernel/Kconfig kernel/sch_psp.c kernel/sch_psp.h
tar -cjf ${D}/usr/ppatch/dev-libs/libnl/psp.tar.bz2 pspd/*.c pspd/*.h
}

pkg_postinst(){
ewarn
ewarn "=================================================="
ewarn "= Now you may (or must):                         ="
ewarn "= # emerge libnl iproute2 *-sources              ="
ewarn "=================================================="
ebeep 5
}

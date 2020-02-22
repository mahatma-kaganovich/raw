# Copyright 1999-2018 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

#ESVN_REPO_URI="http://pspacer.googlecode.com/svn/branches/devel/"
EAPI=5

EGIT_REPO_URI="https://github.com/mahatma-kaganovich/pspacer.git"
EGIT_BRANCH="devel"
inherit eutils git-r3 raw

DESCRIPTION="PSPacer is a precise software pacer of IP traffic for Linux"
#HOMEPAGE="http://www.gridmpi.org/gridtcp.en.jsp"
#HOMEPAGE="http://code.google.com/p/pspacer/"
HOMEPAGE="https://github.com/mahatma-kaganovich/pspacer/tree/devel"
SRC_URI=""
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~*"
IUSE="debug doc"
DEPEND="doc? ( app-text/asciidoc )
	app-portage/ppatch"
PDEPEND="sys-apps/iproute2
	|| ( virtual/linux-sources virtual/linux-kernel )"
#	=dev-libs/libnl-1.0_pre6-r1

src_compile(){
m=""
cf="--without-iproute2 --without-libnl"
use debug && cf="${cf} --enable-debug"
use doc && m="${m} doc"
test ${m} && econf ${cf} && emake ${m}
}

src_install(){
cp -aT "$FILESDIR" "${D}" || die
rm -Rf `find "${D}" -name ".*"`
cd ${S}
#use doc && einstall DESTDIR=${D} docs-install
use doc && cd doc && dodoc * && cp -at ${D}usr/share/doc/${PF}/${DOCDESTTREE} fig/* --parents
p="/usr/ppatch/dev-libs/libnl/compile/"
mkdir ${D}${p} --parents
cp ${S}/patch/* ${D}${p} -Rf
tar -cjf ${D}/usr/ppatch/sys-apps/iproute2/compile/psp.tar.bz2 kernel/sch_psp.h tc/q_psp.c man/man8/tc-psp.8
tar -cjf ${D}/usr/ppatch/virtual/linux-sources/compile/psp.tar.bz2 kernel/Kconfig kernel/sch_psp.c kernel/sch_psp.h
tar -cjf ${D}/usr/ppatch/dev-libs/libnl/psp.tar.bz2 pspd/*.c pspd/*.h
}

# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6
inherit eutils


MY_PV="2013-04-09-1007"
#MY_PV="0.9.2"
DESCRIPTION="SWF Tools is a collection of SWF manipulation and generation utilities"
HOMEPAGE="http://www.swftools.org/"
SRC_URI="http://www.swftools.org/${PN}-${MY_PV}.tar.gz
	https://raw.githubusercontent.com/pld-linux/swftools/master/swftools-poppler.patch
	https://raw.githubusercontent.com/pld-linux/swftools/master/swftools-poppler2.patch
	https://raw.githubusercontent.com/pld-linux/swftools/master/swftools-poppler-0.32.patch"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~hppa ~ppc ~sparc ~x86"
IUSE=""

RDEPEND="
	app-text/poppler
	media-libs/freetype:2
	media-libs/giflib:0=
	>=media-libs/t1lib-1.3.1:5
	virtual/jpeg:0
"
DEPEND="${RDEPEND}
	!<media-libs/ming-0.4.0_rc2
"

S="${WORKDIR}/${PN}-${MY_PV}"

src_prepare() {
	epatch "${DISTDIR}"/swftools-poppler{,2,-0.32}.patch
#	epatch "${FILESDIR}"/${P}_general.patch
	epatch "${FILESDIR}"/${P}_giflib.patch
	epatch "${FILESDIR}"/${P}_giflib5.patch
	export CFLAGS="$CFLAGS `pkg-config --cflags poppler`"
	export LDFLAGS="$LDFLAGS `pkg-config --libs poppler`"
}

src_configure() {
	econf --enable-poppler
	# disable the python interface; there's no configure switch; bug 118242
	echo "all install uninstall clean:" > lib/python/Makefile
}

src_compile() {
	emake FLAGS="${CFLAGS}"
}

src_install() {
	einstall
	dodoc AUTHORS ChangeLog
}

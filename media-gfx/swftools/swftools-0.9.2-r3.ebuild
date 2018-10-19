# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=7
inherit eutils


MY_PV="2013-04-09-1007"
#MY_PV="0.9.2"
DESCRIPTION="SWF Tools is a collection of SWF manipulation and generation utilities"
HOMEPAGE="http://www.swftools.org/"
SRC_URI="http://www.swftools.org/${PN}-${MY_PV}.tar.gz
	http://http.debian.net/debian/pool/main/s/swftools/swftools_0.9.2+git20130725-4.1.debian.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~hppa ~ppc ~sparc ~x86"
IUSE=""

RDEPEND="
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
	default
	eapply "${FILESDIR}"/${P}_giflib.patch "${WORKDIR}"/debian/patches
	echo >lib/python/Makefile.in
}

src_install() {
	emake prefix="$D/usr" datadir="$D/usr/share" infodir="$D/usr/share/info" localstatedir="$D/var/lib" mandir="$D/usr/share/man" sysconfdir="$D/etc"  install
	dodoc AUTHORS ChangeLog
}

# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: blah

EAPI="2"

inherit eutils autotools

DESCRIPTION="Open Source implementation of the ITU H.323 teleconferencing protocol, new fork"
HOMEPAGE="http://www.h323plus.org/"
SRC_URI="http://www.h323plus.org/source/download/${PN}-v${PV//./_}.zip"

LICENSE="MPL-1.1"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="debug ssl"

DEPEND="net-libs/ptlib
	media-video/ffmpeg
	ssl? ( dev-libs/openssl )
	!net-libs/openh323"
RDEPEND="${DEPEND}"

S="${WORKDIR}/${PN}"

src_prepare(){
	epatch "${FILESDIR}"/h323plus-install.patch
	eautoreconf
}

src_configure(){
	HAS_PTLIB=/usr PTLIB_CONFIG=/usr/bin/ptlib-config econf
}

src_compile() {
	emake $(use debug||echo notrace) || die
}

src_install() {
	emake PREFIX=/usr DESTDIR="${D}" $(use debug||echo notrace) install || die
	cd "${D}"/usr/$(get_libdir) || die
	local i f
	for i in libh323_linux_*; do
		[[ -L "$i" ]] && continue
		f="$i"
		ln -s "${i}" "${i/_n./_r.}" ||
		ln -s "${i}" "${i/_r./_n.}"
	done
	for i in libh323_linux_*; do
		[[ -e "$i" ]] && continue
		rm "$i"
		ln -s "$f" "$i"
	done
}

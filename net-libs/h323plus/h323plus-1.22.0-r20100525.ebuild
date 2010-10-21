# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: blah

EAPI="2"

inherit eutils autotools multilib

r="${PVR#*-r}"

DESCRIPTION="Open Source implementation of the ITU H.323 teleconferencing protocol, new fork"
HOMEPAGE="http://www.h323plus.org/"
if [[ -z "$r" ]]; then
	SRC_URI="http://www.h323plus.org/source/download/${PN}-v${PV//./_}.tar.gz
	http://www.h323plus.org/source/download/plugins-v${PV//./_}.tar.gz"
else
	SRC_URI="http://prdownloads.sourceforge.net/openh323gk/h323plus-${PVR#*-r}.tar.gz?download -> ${PN}-${PVR}.tar.gz"
fi
LICENSE="MPL-1.1"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="debug ssl x264 theora"
DEPEND="net-libs/ptlib
	media-video/ffmpeg
	ssl? ( dev-libs/openssl )
	x264? ( media-libs/x264 )
	theora? ( media-libs/libtheora )
	!net-libs/openh323
	media-libs/speex"
RDEPEND="${DEPEND}"
S="${WORKDIR}/${PN}"

src_prepare(){
	use x264 && export ac_cv_lib_x264_x264_encoder_open=yes
	export with_ffmpeg_src_dir=/usr/include

	mv "${WORKDIR}"/plugins "${S}"
	epatch "${FILESDIR}"/h323plus-install.patch
	eautoreconf
}

src_configure(){
	HAS_PTLIB=/usr PTLIB_CONFIG=/usr/bin/ptlib-config econf $(use_enable x264) $(use_enable theora) || die
}

opt(){
	use debug&&echo debug||echo opt # NOTRACE=1
}

src_compile() {
	emake $(opt) || die
	emake -C "${S}"/plugins $(opt) || die
}

src_install() {
	emake PREFIX=/usr DESTDIR="${D}" install || die
	emake PREFIX=/usr DESTDIR="${D}" -C "${S}"/plugins install || die
	libdir=$(get_libdir)
	cd "${D}"/usr/"${libdir}" || die
	local i f=""
	for i in libh323_linux_*; do
		[[ -L "$i" ]] && continue
		[[ -f "$i" ]] || continue
		f="$i"
		ln -s "${i}" "${i/_n./_r.}" ||
		ln -s "${i}" "${i/_r./_n.}"
	done
	for i in libh323_linux_*; do
		[[ -e "$i" ]] && continue
		rm "$i"
		ln -s "$f" "$i"
	done
#	ln -s openh323 "${D}"/usr/share/h323plus
	dosed "s:^OH323_LIBDIR = \$(OPENH323DIR).*:OH323_LIBDIR = /usr/${libdir}:" \
		/usr/share/openh323/openh323u.mak
	dosed "s:^OH323_INCDIR = \$(OPENH323DIR).*:OH323_INCDIR = /usr/include/openh323:" \
		/usr/share/openh323/openh323u.mak
	dosed "s:^\(OPENH323DIR[ \t]\+=\) ${S}:\1 /usr/share/openh323:" \
		/usr/share/openh323/openh323u.mak
}

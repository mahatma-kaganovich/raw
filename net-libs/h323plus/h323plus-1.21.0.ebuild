# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: blah

EAPI="2"

cvs=""
case "${PVR}" in
9999*)
	cvs=cvs
	ECVS_SERVER="h323plus.cvs.sourceforge.net:/cvsroot/h323plus"
	ECVS_MODULE="h323plus"
	ECVS_USER="anonymous"
	ECVS_PASS=""
;;
*-r*)
	SRC_URI="http://prdownloads.sourceforge.net/openh323gk/h323plus-${PVR#*-r}.tar.gz?download -> ${PN}-${PVR}.tar.gz"
;;
*)
	SRC_URI="http://www.h323plus.org/source/download/${PN}-v${PV//./_}.tar.gz
	http://www.h323plus.org/source/download/plugins-v${PV//./_}.tar.gz"
;;
esac

inherit flag-o-matic eutils autotools multilib ${cvs}

DESCRIPTION="Open Source implementation of the ITU H.323 teleconferencing protocol, new fork"
HOMEPAGE="http://www.h323plus.org/"
LICENSE="MPL-1.1"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="debug ssl x264 theora"
DEPEND="net-libs/ptlib[snmp]
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
	egrep -q '"codecs.h"' include/h323caps.h || sed -i -e 's:../include/codecs.h:codecs.h:' include/h323caps.h
	mv "${WORKDIR}"/plugins "${S}"
	epatch "${FILESDIR}"/h323plus-install.patch
	eautoreconf
}

src_configure(){
	export HAS_PTLIB="${ROOT}/usr"
	export PTLIB_CONFIG="${HAS_PTLIB}/bin/ptlib-config"
	append-cflags `$PTLIB_CONFIG --ccflags`
	econf $(use_enable x264) $(use_enable theora) || die
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

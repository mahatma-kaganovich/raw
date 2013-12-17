# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: blah

EAPI="2"

cvs=""
case "${PV}" in
9999*)
	cvs=cvs
	ECVS_SERVER="${PN}.cvs.sourceforge.net:/cvsroot/${PN}"
	ECVS_MODULE="${PN}"
	ECVS_USER="anonymous"
	ECVS_PASS=""
;;
*_pre*)
	SRC_URI="mirror://sourceforge/openh323gk/${PN}-${PV#*_pre}.tar.gz?download -> ${P}.tar.gz"
;;
*)
	SRC_URI="http://www.h323plus.org/source/download/${P}.tar.gz"
;;
esac

inherit flag-o-matic eutils autotools multilib ${cvs}

DESCRIPTION="Open Source implementation of the ITU H.323 teleconferencing protocol, new fork"
HOMEPAGE="http://www.h323plus.org/"
LICENSE="MPL-1.1"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="debug ssl ffmpeg local +full embedded"
DEPEND="ffmpeg? ( media-video/ffmpeg[encode] )
	ssl? ( dev-libs/openssl )
	!local? (
		media-sound/gsm
		>=media-libs/speex-1.2_beta
		dev-libs/ilbc-rfc3951
	)
	!net-libs/openh323
	"
if [[ "${PV}" > 1.21.0 ]]; then
	DEPEND+="|| ( <net-libs/ptlib-2.8[-dtmf,debug,snmp] >net-libs/ptlib-2.8[snmp] )
	x264? (
		media-video/ffmpeg
		media-libs/x264
	)
	celt? ( >=media-libs/celt-0.5.0 )
	sbc? ( media-libs/libsamplerate )"
#	capi? ( net-dialup/capi4k-utils )
#	ixj? ( sys-kernel/linux-headers )
#	fax? ( media-libs/spandsp )
#	theora? ( media-libs/libtheora )
	IUSE+=" x264 celt sbc" # theora fax ixj capi vpb
else
	DEPEND+="<net-libs/ptlib-2.8[snmp]"
fi
RDEPEND="${DEPEND}"
#S="${WORKDIR}/${PN}"

src_prepare(){
	use x264 && export ac_cv_lib_x264_x264_encoder_open=yes
	export with_ffmpeg_src_dir="$ROOT"/usr/include
	egrep -q '"codecs.h"' include/h323caps.h || sed -i -e 's:../include/codecs.h:codecs.h:' include/h323caps.h
	mv "${WORKDIR}"/plugins "${S}"
	epatch "${FILESDIR}"/h323plus-install.patch
	epatch "${FILESDIR}"/h323plus-notrace.patch
	eautoreconf
}

force(){
	use $1 && return
	shift
	while [[ -n "$*" ]]; do
		sed -i -e "s:HAVE_$1=yes:HAVE_$1=no:g" plugins/configure
		shift
	done
}

src_configure(){
	export HAS_PTLIB="${ROOT}/usr"
	export PTLIB_CONFIG="${HAS_PTLIB}/bin/ptlib-config"
	force ffmpeg H263P MPEG4
	append-cflags `$PTLIB_CONFIG --ccflags`
	econf \
		--with-plugin-installdir="ptlib-`$PTLIB_CONFIG --version`" \
		$(use_enable x86 libavcodec-stackalign-hack) \
		--with-libavcodec-source-dir="${ROOT}"/usr/include \
		$(use_enable debug) \
		$(use_enable x264) \
		$(use_enable theora) \
		$(use_enable sbc) \
		$(use_enable celt) \
		$(use_enable capi) \
		$(use_enable vpb) \
		$(use_enable ixj) \
		$(use_enable fax spandsp) \
		$(use_enable local localgsm) \
		$(use_enable local localspeex) \
		$(use_enable local localilbc) \
		$(use_enable full default-to-full-capabilties) \
		$(use_enable embedded x264-link-static) \
		|| die
#		$(use_enable embedded embeddedgsm)
}

opt(){
	use debug&&echo debug||echo opt # NOTRACE=1
}

src_compile() {
	emake $(opt) || die
	emake -C "${S}"/plugins $(opt) || die
}

src_install() {
	local i f=""
	emake PREFIX=/usr DESTDIR="${D}" install || die
	emake PREFIX=/usr DESTDIR="${D}" -C "${S}"/plugins install || die
	libdir="$(get_libdir)"
	cd "${D}"/usr/"${libdir}" || die
	[[ -e "pwlib" ]] && dosym ../pwlib "/usr/${libdir}/ptlib-`$PTLIB_CONFIG --version`/pwlib"
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
EAPI=4
WANT_AUTOCONF="2.1"


hg=""
[[ "${PV}" == 9999* ]] && hg="mercurial cvs git-r3"
inherit ${hg} flag-o-matic toolchain-funcs eutils mozcoreconf-2_ mozconfig-3 makeedit multilib autotools mozextension fdo-mime java-pkg-opt-2
#python

: ${FILESDIR:=${EBUILD%/*}/files}

MY_PN="${PN/fennec/mobile}"
MY_PN="${MY_PN/shiretoko/firefox}"
MY_PN="${MY_PN/bonecho/firefox}"
MY_PN="${MY_PN/minefield/firefox}"
MY_PN="${MY_PN/mozilla-firefox/firefox}"
MY_PN="${MY_PN/aurora/firefox}"

MY_PV="${PV/_/}"
MY_PV="${MY_PV/beta/b}"
MY_PV="${MY_PV/alpha/a}"
MY_P="${MY_PN}-${MY_PV}"
MY_P="${MY_P/mobile/fennec}"
EMVER="1.1.2"
PATCH="http://dev.gentoo.org/~polynomial-c/seamonkey-2.0.6-patches-01.tar.bz2"

case "${MY_PN}" in
mobile)
	MOZVER="1.9.2"
;;
seamonkey)
	MOZVER="1.9.1"
	# empty: from hg
	case "${PV}" in
	*alpha*)MOZVER="central";;
	*)LANGS="en be ca cs de es_AR es_ES fr gl hu it ja ka lt nb_NO nl pl pt_PT ru sk sv_SE tr";;
	esac
;;
esac

IUSE="-java mozdevelop moznoirc moznoroaming postgres startup-notification
	debug minimal directfb moznosystem +threads jssh python mobile static
	moznomemory accessibility vanilla xforms gio +alsa
	+custom-cflags +custom-optimization system-xulrunner +libxul system-nss system-nspr X
	bindist flatfile profile ipv6 moznopango e10s force-shared-static ipccode egl +force-gl gles2 xrender
	gstreamer"
#	qt-experimental"
REQUIRED_USE_="
	gles2? ( egl )
	jssh? ( !static )
	startup-notification? ( X )
"

[[ "$EAPI" != 3 ]] && REQUIRED_USE="$REQUIRED_USE"

#RESTRICT="nomirror"


SRC_URI="http://releases.mozilla.org/pub/mozilla.org/${MY_PN}/releases/${MY_PV}/source/${MY_P}.source.tar.bz2"

KEYWORDS="amd64 x86"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"

RDEPEND="java? ( >=virtual/jre-1.4 )
	python? ( >=dev-lang/python-2.3 )
	>=sys-devel/binutils-2.16.1
	!moznosystem? (
		!static? ( >=app-text/hunspell-1.2 )
		>=media-libs/lcms-1.17
		app-arch/bzip2
		x11-libs/cairo[directfb=]
		!moznopango? ( x11-libs/pango )
		x11-libs/pixman
		dev-libs/libevent
		alsa? ( media-libs/libvpx )
		dev-python/ply
	)
	gles2? ( || ( media-libs/mesa[gles] media-libs/mesa[gles2] ) )
	egl? ( media-libs/mesa[egl] )
	X? ( >=x11-libs/gtk+-2.8.6 )
	!X? ( x11-libs/gtk+-directfb )
	system-nspr? ( >=dev-libs/nspr-4.7.3 )
	system-nss? ( >=dev-libs/nss-3.12.2 )
	system-xulrunner? ( net-libs/xulrunner )
	alsa? ( media-libs/alsa-lib )
	gstreamer? ( media-libs/gstreamer )
	directfb? ( dev-libs/DirectFB )"

DEPEND=">=dev-lang/python-3.2"

S="${WORKDIR}/comm-${MOZVER}"

force(){
	local i j
	for i in $*; do
		j="${i#-}"
		[[ "$j" == "$i" ]] && IUSE="${IUSE// $i/ +$i}" || IUSE="${IUSE// +$j/ $j}"
	done
}

ll="${MOZVER}"
case "${PV}" in
*alpha*|*beta*)force vanilla;;
esac
if [[ -n "${hg}" ]]; then
	LANGS=""
	IUSE="${IUSE} faststart extra-repo"
	force vanilla
	SRC_URI=""
	if [[ "${PVR}" == *-r9999* ]]; then
		S="${WORKDIR}/comm-central"
		ll="central"
	else
		S="${WORKDIR}/comm-${MOZVER}"
		ll="1.9.${PVR##*r}"
	fi
elif [[ -z "${LANGS}" ]]; then
#	SRC_URI="${SRC_URI} `sed -e 's:^\(.*\) \(.*\)\$:linguas_\1? ( \2 -> mozilla-'"${PV}"'.lang.\1..tar.bz2 ):' <${FILESDIR}/${ll}.langs`"
	SRC_URI="${SRC_URI} `sed -e 's:^\(.*\) \(.*/\)\([^/]*\.tar\.bz2\)\$:linguas_\1? ( \2\3 -> l10n-mozilla-'"${MOZVER}"'.\1.\3 ):' <${FILESDIR}/${ll}.langs`"
fi

case "${ll}" in
central)
sv_v=44f3007c3002
xf_v=a82c84521604
;;
*)
sv_v=fc72c38dc393
xf_v=b4b01fd808f2
;;
esac

[[ -z "${hg}" ]] && SRC_URI="${SRC_URI}
		xforms? ( http://hg.mozilla.org/schema-validation/archive/${sv_v}.tar.bz2 -> schema-validation-${sv_v}.tar.bz2
		http://hg.mozilla.org/xforms/archive/${xf_v}.tar.bz2 -> xforms-${xf_v}.tar.bz2 )"


if [[ -z "${LANGS}" ]]; then
	LANGS="en_US $(sed -e 's: .*::g' <"${FILESDIR}/${ll}.langs")"
else
	for l in ${LANGS}; do
		[[ ${l} == "en" ]] || [[ ${l} == "en_US" ]] || SRC_URI="${SRC_URI} linguas_${l}? ( http://releases.mozilla.org/pub/mozilla.org/${MY_PN}/releases/${MY_PV}/langpack/${MY_P}.${l/_/-}.langpack.xpi -> ${MY_P}-${l/_/-}.xpi )"
	done
fi

for l in ${LANGS}; do
	IUSE="${IUSE} linguas_${l}"
done

case "${MY_PN}" in
seamonkey)
	DESCRIPTION="Mozilla Application Suite - web browser, email, HTML editor, IRC"
	HOMEPAGE="http://www.seamonkey-project.org/"
	export MOZ_CO_PROJECT=suite
	IUSE="${IUSE} moznocompose moznomail crypt moznocalendar"
	[[ -z "${hg}" ]] && SRC_URI="${SRC_URI} crypt? ( !moznomail? ( http://dev.gentoo.org/~anarchy/dist/enigmail-${EMVER}.tar.gz ) )"
	RDEPEND="${RDEPEND} crypt? ( !moznomail? ( >=app-crypt/gnupg-1.4 ) )"
	S1="${S}/mozilla"
	[[ -z "${hg}" ]] && force -libxul
	: ${EHG_TAG_seamonkey:=SEAMONKEY}
;;
firefox)
	PATCH=""
	DESCRIPTION="${PN} Web Browser"
	HOMEPAGE="http://www.mozilla.org/projects/${PN}"
	export MOZ_CO_PROJECT=browser
	S="${S/comm-/mozilla-}"
	S1="${S}"
	[[ "$PN" == "shiretoko" ]] && IUSE="${IUSE} +release-tag"
	: ${EHG_TAG_shiretoko:=FIREFOX}
;;
mobile)
	PATCH=""
	DESCRIPTION="Fennec Web Browser"
	HOMEPAGE="http://www.mozilla.org/projects/fennec/"
	export MOZ_CO_PROJECT="xulrunner mobile"
	S="${S/comm-/mozilla-}"
	S1="${S}"
	SRC_URI="${SRC_URI//\/1.0rc3\///1.0/}"
	SRC_URI="${SRC_URI//\/1.0.1\///1.0.1rc1/}"
	: ${EHG_TAG_fennec:=FENNEC}
;;
*)
	die
;;
esac

extensions="${S}/mailnews/extensions/enigmail ${S1}/extensions/ipccode"

[[ -n "${PATCH}" ]] && SRC_URI="${SRC_URI}  !vanilla? ( ${PATCH} )"

# wireless-tools requred by future (mercurial repo), maybe now too
#       qt-experimental? (
#               x11-libs/qt-gui
#               x11-libs/qt-core )
DEPEND="java? ( >=virtual/jdk-1.4 )
	${RDEPEND}
	dev-lang/perl
	dev-util/pkgconfig
	postgres? ( >=virtual/postgresql-server-7.2.0 )"

export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1
export PERL="/usr/bin/perl"

LDAP(){
#	use ldap || return 1
	return 0
}

pkg_setup() {
	moz_pkgsetup
	local i f f1
	[[ "$EAPI" == 3 ]] && for i in ${REQUIRED_USE_}; do
		case "$i" in
		\)|\();;
		*\?)f=${i%?};;
		*)use $f && ! use $i && die "Useflags mismatch: $f? ( $i )";;
		esac
	done
#	python_set_active_version 3
#	python-_pkg_setup
}

src_unpack() {
	local i l
	mkdir "${WORKDIR}"/l10n
	for i in ${A} ; do
		cd "${WORKDIR}" || die
		case $i in
		*.lang.*)
			unpack ${i}
			l="${i#*.lang.}"
			l="${l%%.*}"
			mv "${WORKDIR}/${l}"-* "${WORKDIR}/l10n/${l//_/-}"
		;;
		*.xpi) xpi_unpack ${i} ;;
		*) unpack ${i} ;;
		esac
	done
}

src_prepare(){
	local i i1 i2
	java-pkg-opt-2_src_prepare

	i="${S1%/*}/mozilla"
	if [[ "${i}" != "${S1}" ]] ; then
		rm -Rf "$i"
		ln -s "${S1}" "$i"
	fi

	if use !vanilla && [[ -n "${PATCH}" ]]; then
		rm ${WORKDIR}/001*
		cd "${S}" || die
		EPATCH_EXCLUDE="108-fix_ftbfs_with_cairo_fb.patch" \
		EPATCH_SUFFIX="patch" EPATCH_FORCE="yes" epatch "${WORKDIR}"
	fi

	cd "${S}"
	[[ -e "${FILESDIR}/${PV}" ]] &&
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${FILESDIR}"/${PV}

	for i in $extensions "${S1}"/extensions/{xforms,schema-validation}; do
		mv "${WORKDIR}/${i##*/}" "$i"
	done
	for i in $extensions; do
		cd "$i" 2>/dev/null || continue
		sed -i -e 's:^\(#include "mimehdrs2.h"\)$:#include <ctype.h>\n\1:' src/mimehdrs2.cpp
		./makemake -r
	done

	# Fix scripts that call for /usr/local/bin/perl #51916
	ebegin "Patching smime to call perl from /usr/bin"
	sed -i -e '1s,usr/local/bin/perl,usr/bin/perl,' "${S1}"/security/nss/cmd/smimetools/smime
	eend $? || die "sed failed"

	elog "Other misc. patches"
	## gentoo install dirs
	sed -i -e 's%-$.MOZ_APP_VERSION.$%%g' "${S}"/config/autoconf.mk.in
	# search +minimal
	sed -i -e 's:^\( *setHelpFileURI\):if (typeof(setHelpFileURI) != "undefined") \1:g' "${S}"/suite/mailnews/search/*.js

	if use python; then
		sed -i -e 's:^DEPTH[	 ]*=[	 ]*\.$:DEPTH= ../..:g' "${S1}"/extensions/python/Makefile.in
		sed -i -e 's:^DEPTH[	 ]*=[	 ]*\.\.$:DEPTH=../../..:g' "${S1}"/extensions/python/*/Makefile.in
		sed -i -e 's:^DEPTH[	 ]*=[	 ]*\.\./\.\.$:DEPTH=../../../..:g' "${S1}"/extensions/python/*/*/Makefile.in
		sed -i -e 's:^DEPTH[	 ]*=[	 ]*\.\./\.\./\.\.$:DEPTH=../../../../..:g' "${S1}"/extensions/python/*/*/*/Makefile.in
	fi

	sed -i -e 's%^#elif$%#elif 1%g' "${S1}"/toolkit/xre/nsAppRunner.cpp
	use X || sed -i -e 's:gtk-2\.0:gtk-directfb-2.0:g' -e 's:GDK_PACKAGES=directfb:GDK_PACKAGES="directfb gdk-directfb-2.0":g' `find "${S}" -name configure.in` `find "${S}" -name "Makefile*"`
	if use !moznosystem; then
		sed -i -e 's:^\(#include <limits.h>\)$:\1\n#define cairo_surface_set_subpixel_antialiasing(x,y)\n#define cairo_surface_get_subpixel_antialiasing(x) 1\n#define CAIRO_SUBPIXEL_ANTIALIASING_ENABLED 1:' "${S1}"/gfx/thebes/gfxASurface.cpp
		sed -i -e 's:^\(#include "cairo.h"\)$:\1\n#include <cairo-tee.h>:' "${S1}"/gfx/thebes/gfxTeeSurface.cpp
		sed -i -e 's:^cairo-pdf\.h$:cairo-pdf.h\ncairo-tee.h:' "${S1}/config/system-headers" "${S1}/js/src/config/system-headers"
		rm -Rf "${S1}/gfx/cairo"
	fi
#	sed -i -e 's:^\(PR_STATIC_ASSERT.*CAIRO_SURFACE_TYPE_SKIA.*\)$:#if CAIRO_HAS_SKIA_SURFACE\n\1\n#endif:' "${S1}"/gfx/thebes/gfxASurface.cpp
	LDAP || sed -i -e 's:^#ifdef MOZ_LDAP_XPCOM$:ifdef MOZ_LDAP_XPCOM:' -e 's:^#endif$:endif:' "${S}"/bridge/bridge.mk
	touch "${S}"/directory/xpcom/datasource/nsLDAPDataSource.manifest
#	sed -i -e 's:\(return XRE_InitEmbedding.*\), nsnull, 0:\1:' "${S1}"/extensions/java/xpcom/src/nsJavaInterfaces.cpp
#	use opengl && sed -i -e 's: = GLX$: = EGL:' "${S1}"/{gfx/thebes,content/canvas/src}/Makefile*
	if use force-gl; then
		sed -i -e 's:if (mIsMesa):if (0):' "${S1}"/widget/xpwidgets/GfxInfoX11.cpp
		# dumb
		sed -i -e 's%return nsIGfxInfo::FEATURE_BLOCKED_[A-Z0-9_]*%return nsIGfxInfo::FEATURE_NO_INFO%g' "${S1}"/widget/xpwidgets/*.cpp
		ewarn "Enabling all hardware for OpenGL. Just USE='-force-gl' if problems."
	fi
	use gles2 || sed -i -e '/#define USE_GLES2 1/d' "${S1}"gfx/gl/GLContext.h
	sed -i -e 's:MOZ_PLATFORM_MAEMO:MOZ_EGL_XRENDER_COMPOSITE:' "${S1}"/gfx/{thebes/gfxXlibSurface.*,layers/*/*} $(use xrender || echo "${S1}/gfx/thebes/gfxPlatformGtk.h") $(use gles2 && echo "${S1}/gfx/layers/Makefile.in")
	echo 'ifeq ($(GL_PROVIDER),EGL)
CXXFLAGS += -fpermissive
endif' >>"${S1}"/gfx/gl/Makefile.in

	sed -i -e 's:header\.py --cachedir=\. --regen:header.py --cachedir=cache --regen:' "${S1}"/xpcom/idl-parser/Makefile.in
	ln -s {cache,"${S1}"/xpcom/idl-parser}/xpidllex.py
	ln -s {cache,"${S1}"/xpcom/idl-parser}/xpidlyacc.py

	sed -i -e 's:\r::' "${S}"/db/makefiles.sh

	sed -i -e '/;-/d' -e 's,;+,,' -e 's; DATA ;;' -e 's,;;,,' -e 's,;.*,;,' $(find "${S1}"/security/nss -name '*.def')

	mkdir "${S1}/js/src/.deps"

	for i in "${WORKDIR}"/l10n/*/toolkit/chrome/global/*; do
		[[ -e "${i}" ]] && ln -s "${i}" "${i%/*}/../../../suite/chrome/browser/${i##*/}"
	done
	for i in `find "${S}" -name locales` ; do
		[[ -d "${i}"/en-US ]] || continue
		i1="${i%/locales}"
		i1="${i1#${S1}/}"
		i1="${i1#${S}/}"
		for i2 in "${WORKDIR}"/l10n/*; do
			[[ -d "${i2}/${i1}" ]] && cp -an "${i}"/en-US/* "${i2}/${i1}"
		done
	done

	[[ -e "${S1}/netwerk/protocol/device" ]] && for i in "${S}" "${S1}"; do
		grep -q "^NECKO_PROTOCOLS_DEFAULT=.*device" "${i}"/configure.in ||
			sed -i -e 's:^NECKO_PROTOCOLS_DEFAULT=":NECKO_PROTOCOLS_DEFAULT="device :' "${i}"/configure.in
	done

	if [[ -e "${S}/suite" ]]; then
		mkdir -p "${WORKDIR}"/l10n/en-US/suite
		ln -s "${S}"/suite/debugQA/locales/en-US "${WORKDIR}"/l10n/en-US/suite/debugQA
	fi

	for i in "${S1}/js/src" "${S1}" "${S}" "${S}/ldap/sdks/c-sdk" "${S}/directory/c-sdk" ; do
		cd "${i}" && eautoreconf
	done
}

src_configure(){
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	export LD_RUN_PATH=":${LD_RUN_PATH}"

	use !X && export PKG_CONFIG_PATH="/usr/$(get_libdir)/dfb/usr/$(get_libdir)/pkgconfig:${PKG_CONFIG_PATH}" &&
		export LD_LIBRARY_PATH="/usr/$(get_libdir)/dfb/usr/$(get_libdir):${LD_LIBRARY_PATH}" &&
		export LD_RUN_PATH="/usr/$(get_libdir)/dfb/usr/$(get_libdir):${LD_RUN_PATH}"


	if use python; then
		export MOZ_PYTHON_EXTENSIONS="dom xpcom"
		export MOZ_PYTHON_VER_DOTTED="$(python_get_version)"
		export MOZ_PYTHON_INCLUDES="-I/usr/include/$(PYTHON)"
		export MOZ_PYTHON_LIBDIR="/$(get_libdir)/$(PYTHON)"
		export MOZ_PYTHON_LIBS="-L${MOZ_PYTHON_LIBDIR} -l$(PYTHON)"
	fi

	setup-allowed-flags
	export ALLOWED_FLAGS="${ALLOWED_FLAGS} -fomit-frame-pointer -O3 -mfpmath -msse* -m3dnow* -mmmx -mstackrealign -fPIC"
#	use strip-cflags && strip-flags
	local CF="${CFLAGS}"

	mozconfig_init
	mozconfig_config

	rmopt --with-system-png

	use alpha && append-ldflags "-Wl,--no-relax"
	append-ldflags "-Wl,--no-keep-memory"

	if use moznopango; then
		rmopt able-pango
		mozconfig_annotate -pango --disable-pango
	fi

	mozconfig_annotate 'gentoo' \
		--with-system-bz2 \
		--enable-canvas \
		--enable-image-encoder=all \
		--enable-system-{lcms,pixman,ply} \
		--with-default-mozilla-five-home=${MOZILLA_FIVE_HOME} \
		--with-user-appdir=.mozilla \
		--without-system-png \
		--enable-pref-extensions \
		--enable-raw \
		--disable-tests

	for i in --with-system-libevent --enable-media-plugins --enable-media-navigator --enable-omx-plugin; do
		isopt -${i#--*-} && mozconfig_annotate "gentoo" $i
	done
	isopt -gstreamer && mozconfig_use_enable gstreamer


	local l
	for l in $(langs); do
		if [[ -e "${WORKDIR}/l10n/${l}" ]]; then
			mozconfig_annotate 'l10n' --with-l10n-base="${WORKDIR}/l10n" --enable-ui-locale=${l}
		elif [[ "${l}" != "en-US" ]]; then
			continue
		fi
		ewarn "Building only first known locale (${l})"
		break
	done

	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks

	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate 'galeon' --enable-oji --enable-mathml

	# Other moz-specific settings
#	mozconfig_use_enable mozdevelop jsd
	mozconfig_use_enable mozdevelop xpctools
	[[ -e "${S1}"/extensions/python ]] && mozconfig_use_extension python # python/xpcom
#	mozconfig_use_extension python python
	if [[ "${MY_PN}" == "mobile" ]] && [[ -z "${hg}" ]]; then
		( use java || use python ) && ewarn "Useflags 'java' & 'python' ignored here"
	elif use java && grep -q "XRE_InitEmbedding(" "${S1}"/extensions/java/xpcom/src/nsJavaInterfaces.cpp && ! grep -q "XRE_InitEmbedding(" "${S1}"/toolkit/xre/nsEmbedFunctions.cpp; then
		ewarn "JavaXPCOM extension is broken in this version and will be skipped"
		ewarn "Useflag 'java' ignored"
	else
		mozconfig_use_enable java javaxpcom
	fi
	mozconfig_use_extension jssh jssh
#	mozconfig_use_extension widgetutils widgetutils
	mozconfig_use_extension mozdevelop venkman
	mozconfig_use_extension mozdevelop layout-debug
#	mozconfig_use_extension accessibility access-builtin
	if LDAP; then
		mozconfig_annotate +ldap --enable-ldap --enable-ldap-experimental
	else
		mozconfig_annotate -ldap --disable-ldap --disable-ldap-experimental
	fi
	mozconfig_use_with threads pthreads
	mozconfig_use_with X x
	mozconfig_use_enable X plugins
	mozconfig_use_enable ipv6
	mozconfig_use_enable mobile mobile-optimize
	mozconfig_use_enable !moznocalendar calendar
	if use force-shared-static; then
		ewarn "Forced shared or static is experimental or unstable"
		mozconfig_use_enable static
		mozconfig_use_enable static static-mail
		mozconfig_use_enable static js-static
	elif use static; then
		use libxul || mozconfig_use_enable static
		mozconfig_use_enable static static-mail
		[[ "${PVR}" == *9999 ]] && mozconfig_use_enable static js-static-build
	fi
	mozconfig_use_enable !static system-hunspell
	if use threads ; then
		mozconfig_use_enable !moznomemory jemalloc
	else
		mozconfig_annotate "-threads" --disable-jemalloc
		ewarn "jemalloc do not support -threads, disabling jemalloc"
	fi
	mozconfig_use_enable accessibility
	# ignored in 2.0
	rmopt -gio
	mozconfig_use_enable gio
	mozconfig_use_enable faststart

	mozconfig_use_enable alsa ogg
	mozconfig_use_enable alsa wave
	isopt '\--disable-webm' && mozconfig_use_enable alsa webm
	use alsa && mozconfig_annotate "alsa" --with-system-libvpx

	isopt '\--disable-ipc' && mozconfig_use_enable libxul ipc
	mozconfig_use_enable libxul
	if use flatfile; then
		mozconfig_annotate "flatfile" --enable-chrome-format=symlink
	elif SM || use !libxul; then
		mozconfig_annotate "-libxul,-flatfile" --enable-chrome-format=jar
	fi

	mozconfig_use_enable startup-notification libnotify

	if use moznoirc; then
		mozconfig_annotate '+moznocompose +moznoirc' --enable-extensions=-irc
	elif [[ -e "${S1}/extensions/irc" ]]; then
		SM || mozconfig_annotate '+moznocompose -moznoirc' --enable-extensions=irc
	fi

	if use moznoroaming ; then
		mozconfig_annotate '+moznoroaming' --enable-extensions=-sroaming
	fi

	if use postgres ; then
		mozconfig_annotate '+postgres' --enable-extensions=sql
		export MOZ_ENABLE_PGSQL=1
		export MOZ_PGSQL_INCLUDES=/usr/include
		export MOZ_PGSQL_LIBS=/usr/$(get_libdir)
	fi

	if use moznomail; then
		mozconfig_annotate "+moznomail" --disable-mailnews
	fi

	if use moznocompose; then
		if use moznoirc && use moznomail; then
			mozconfig_annotate "+moznocompose" --disable-composer
		fi
	fi

	use xforms && mozconfig_annotate "+xforms" --enable-extensions=xforms,schema-validation
	use xforms && ewarn "xforms may required 'moznosystem' useflag to build and completely unsure"
	use ipccode && mozconfig_annotate "+ipccode" --enable-extensions=ipccode

	if use minimal; then
#		use mobile && mozconfig_annotate +minimal,+mobile
#			--with-embedding-profile=minimal
		mozconfig_annotate +minimal \
			--disable-postscript \
			$(SM && echo "--disable-help-viewer") \
			--disable-safe-browsing \
			--disable-url-classifier \
			--enable-necko-small-buffers \
			--disable-parental-controls
	else
		mozconfig_annotate -minimal \
			--enable-postscript \
			$(SM && echo "--enable-help-viewer") \
			--enable-safe-browsing \
			--enable-url-classifier \
			--disable-necko-small-buffers \
			--enable-parental-controls
	fi

	mozconfig_annotate broken \
		--disable-mochitest \
		--disable-crashreporter

	# lost optimizations, etc
	rmopt -strip
	mozconfig_use_enable !debug strip
	mozconfig_use_enable !debug strip-libs
	mozconfig_use_enable !debug install-strip

	isopt egl-xrender-composite && mozconfig_use_enable egl egl-xrender-composite
	isopt e10s-compat && mozconfig_use_enable e10s e10s-compat

	use custom-cflags && export CFLAGS="${CF}"
	filter-flags -fgraphite-identity
	use gles2 && append-flags -DUSE_GLES2=1
	for i in -Ofast -O3; do
		is-flag $i || continue
		sed -i -e 's:\=\-O2:='"$i"':g' .mozconfig
		break
	done

	# required for sse prior to gcc 4.4.3, may be faster in other cases
	[[ "${ARCH}" == "x86" ]] && append-flags -mstackrealign
#	append-flags -fno-unroll-loops
	export CXXFLAGS="${CFLAGS}"


#	! SM && use directfb && sed -i -e 's%--enable-default-toolkit=cairo-gtk2%--enable-default-toolkit=cairo-gtk2-dfb%g' "${S}"/.mozconfig

	if use qt-experimental ; then
		sed -i -e 's%--enable-default-toolkit=cairo-gtk2%--enable-default-toolkit=cairo-qt%g' "${S}"/.mozconfig
		rmopt -system-cairo
		mozconfig_annotate "qt-experimental" --disable-system-cairo
	fi

	use moznosystem &&
	    einfo "USE 'moznosystem' flag - disabling usage system libs" &&
	    sed -i -e 's/--enable-system-\([^ =]*\).*/--disable-system-\1/g' -e 's/--with-system-\([^ =]*\).*/--without-system-\1/g' "${S}"/.mozconfig


	use system-xulrunner && mozconfig_annotate system-xulrunner --with-system-libxul --with-libxul-sdk=/usr/$(get_libdir)/xulrunner-devel-"`pkg-config libxul --modversion`"

	rmopt system-nss
	rmopt system-nspr
	# mozilla.org alredy source of last versions:
	mozconfig_use_with system-nss
	mozconfig_use_with system-nspr

#	case "${MY_PN}" in
#	firefox) mozconfig_annotate '' --enable-faststripe ;;
#	esac

	echo "" >>"${S}"/.mozconfig

	rmopt -branding
	branding=''
	case "${PN}" in
	*minefield*)
		mozconfig_annotate '' --enable-faststripe
		branding=browser/branding/nightly
	;;
	*bonecho*|*shiretoko*)
		branding=browser/branding/unofficial
	;;
	*aurora*)
		branding=browser/branding/aurora
	;;
	*firefox*)
		mozconfig_use_enable !bindist official-branding
#		branding=browser/branding/official
		einfo
		elog "You may not redistribute this build to any users on your network"
		elog "or the internet. Doing so puts yourself into"
		elog "a legal problem with Mozilla Foundation"
	;;
	esac
	if [[ -n "$branding" ]]; then
		local m="${branding//browser/mobile}"
		use mobile && [[ -e "${S}/${m}" ]] && branding="$m"
		mozconfig_annotate '' --with-branding=$branding
	fi
	export branding

	export MAKEOPTS="$MAKEOPTS installdir=$MOZILLA_FIVE_HOME sdkdir=$MOZILLA_FIVE_HOME-devel includedir=/usr/include/${PN} idldir=/usr/share/idl/${PN}"

	# prepare to standard configure/make if single project or to "make -f client.mk" if multiple
	local i a=""
	for i in ${MOZ_CO_PROJECT}; do
		use system-${i} || a="${a} ${i}"
	done
	a="${a# }"
	if [[ "${a// }" == "${a}" ]]; then
		mozconfig_annotate '' --enable-application=${a}
	else
		[[ "${a//xulrunner}" != "${a}" ]] && export LD_RUN_PATH="${MOZILLA_FIVE_HOME}/xulrunner:${LD_RUN_PATH}"
		echo "mk_add_options MOZ_BUILD_PROJECTS=\"${a}\"
mk_add_options MOZ_MAKE_FLAGS=\"$MAKEOPTS\"
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/../base" >>"${S}"/.mozconfig
		[[ "${a// }" == "${a}" ]] && ln -s "${S}" "${WORKDIR}/base/$a"
		for i in ${a}; do
			echo "ac_add_app_options ${i} --enable-application=${i}" >>"${S}"/.mozconfig
			[[ "${a//xulrunner}" != "${a}" ]] && [[ "${i}" != "xulrunner" ]] &&
				echo "ac_add_app_options ${i} --with-libxul-sdk=../xulrunner/dist"" ">>"${S}"/.mozconfig
		done
	fi

	# Finalize and report settings
	mozconfig_final
	export MOZCONFIG="${S}/.mozconfig"

	if [[ $(gcc-major-version) -lt 4 ]]; then
		append-cxxflags -fno-stack-protector
	fi

	if ! grep -q "^mk_" "${S}"/.mozconfig; then
		CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
		econf || die
	fi

	if use directfb && use vanilla && grep -vq "cairo-gtk2-dfb" "${S}"/.mozconfig; then
		local dl=`pkg-config directfb --libs`
#		local dl="-ldirectfb -ldirect"
		sed -i -e 's%\(^MOZ_DFB.*\)%\1 1%' \
			-e 's%\(^OS_LIBS.*\)%\1 '"${dl}"'%' \
			"${S1}"/config/autoconf.mk
	fi


	# This removes extraneous CFLAGS from the Makefiles to reduce RAM
	# requirements while compiling
	edit_makefiles

}

_package(){
	local i i1

	for i in "${WORKDIR}"/base/*; do
		i1="$i"
		[[ -e "$i" ]] || {
			i="${S}"
			i1="${S1}/dist"
		}
		if [[ -n "$1" && "$1" != en-US ]]; then
			elog "Setting default locale to $1"
			sed -i -e "s:\"en-US\":\"$1\":g" \
			    ${i1}/bin/defaults/pref*/*-l10n.js &&
			    mv "${D}/${MOZILLA_FIVE_HOME}"/* "${i1}/bin/"
		fi
		emake -C "$i" package # -i # eapi 4
	done
}

src_compile() {
	local E o= o1= o2=
	grep -q "^mk_" "${S}"/.mozconfig && o="-f client.mk" && o1=build
	use profile && o2="MOZ_PROFILE_GENERATE=1"
	# sometimes parallel build breaks
	emake $o $o1 $o2 || emake -j1 $o $o1 $o2 || die
	use profile && {
		_package
		emake $o maybe_clobber_profiledbuild
		emake $o $o1 MOZ_PROFILE_USE=1 || die
	}
	for E in $extensions; do
		[[ -e "$E" ]] && ( emake -C "$E" || die )
	done
}

rmopt(){
	sed -i -e "/$*/d" "${S}"/.mozconfig
}

isopt(){
	grep -q "$*" "${S}"/configure.in "${S1}"/configure.in
	return $?
}

icon(){
	local i
	for i in $*; do
		[[ -d "${i}" ]] && for i in $(find "${i}" -name "*_scalable.png") $(find "${i}" -name icon64.png) $(find "${i}" -name icon48.png) ; do
			[[ -f "${i}" ]] && break
		done
		[[ -f "${i}" ]] && break
	done
	[[ -f "${i}" ]] && newicon "${i}" "${PN}"-icon.png
}

src_install() {
	declare MOZILLA_FIVE_HOME=/usr/$(get_libdir)/${PN}

	local LANG=""
	local d
	for l in $(langs); do
		: ${LANG:=${l}}
		for d in "${WORKDIR}/${MY_P}-${l}" "${WORKDIR}/enigmail-${l}-${EMVER}" ; do
			[[ -e "${d}" ]] && xpi_install "${d}"
		done
	done

	_package ${LANG}

	# Most of the installation happens here
	if SM; then
	dodir "${MOZILLA_FIVE_HOME}"
	cp -RL "${S1}"/dist/bin/* "${D}"/"${MOZILLA_FIVE_HOME}"/ ||
	    cp -RL "${WORKDIR}"/base/${MOZ_CO_PROJECT##* }/dist/bin/* "${D}"/"${MOZILLA_FIVE_HOME}"/ ||
	    die "cp failed"
	else
	grep -q "^mk_" "${S}"/.mozconfig && i="-f client.mk" || i=
	emake $i DESTDIR="${D}" install
	use ipccode && cp -L "${S1}"/extensions/ipccode/build/*.so "${D}/${MOZILLA_FIVE_HOME}"/components/
	# do you need this?
	use !mozdevelop && rm -Rf "${D}"/usr/{include,share/idl}
	fi

	# Create directory structure to support portage-installed extensions.
	# See update_chrome() in mozilla-launcher
#	keepdir ${MOZILLA_FIVE_HOME}/chrome.d
#	keepdir ${MOZILLA_FIVE_HOME}/extensions.d
#	cp "${D}"${MOZILLA_FIVE_HOME}/chrome/installed-chrome.txt \
#		"${D}"${MOZILLA_FIVE_HOME}/chrome.d/0_base-chrome.txt

	local Title="${PN^}"
	local Comment="Web Browser"
	local R="${MY_PN}"

	# Install icon and .desktop for menu entry
	case "${PN}" in
	*seamonkey*)
		icon "${S}"/suite/branding/{,nightly/}content
		Title="SeaMonkey"
	;;
	*firefox*)
		icon "${S}"/other-licenses/branding/firefox/content
		Title="Mozilla Firefox"
	;;
	*fennec*)
		icon "${S}"/mobile/branding/{,nightly/}content
	;;
	*)icon "${S}/${branding}";;
	esac
	echo "[Desktop Entry]
Name=${Title}
Comment=${Comment}
Exec=/usr/bin/${PN}-X %U
Icon=${PN}-icon
Terminal=false
Type=Application
MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;
Categories=Network;WebBrowser;">"${WORKDIR}/${PN}.desktop"
	domenu "${WORKDIR}/${PN}.desktop"

	# Create /usr/bin/${PN}
	i="${D}/usr/bin"
	if [[ -e "$i/$R" ]]; then
		# respect install
		[[ "$i/$R" != "$i/$PN" ]] && mv "$i/$R" "$i/$PN"
	else
		make_wrapper ${PN} "${MOZILLA_FIVE_HOME}/${R}"
	fi

	# seamonkey/mail may do illegal output
	echo '#!/bin/sh
# prevent to stalled terminal outputs (seamonkey, etc)
exec /usr/bin/'"${PN}"' "$@" &>/dev/null' >"${WORKDIR}/${PN}-X"
	exeinto /usr/bin
	doexe "${WORKDIR}/${PN}-X"

	# Add vendor
	echo "pref(\"general.useragent.vendor\",\"Gentoo\");" >> `echo "${D}"${MOZILLA_FIVE_HOME}/defaults/pref*/vendor.js`

	# Install rebuild script since mozilla-bin doesn't support registration yet
#	exeinto ${MOZILLA_FIVE_HOME}
#	doexe "${FILESDIR}"/${PN}-rebuild-databases.pl
#	dosed -e 's|/lib/|/'"$(get_libdir)"'/|g' \
#		${MOZILLA_FIVE_HOME}/${PN}-rebuild-databases.pl

	# Install docs
	dodoc "${S1}"/{LEGAL,LICENSE}

	rm "${D}${MOZILLA_FIVE_HOME}"/libnullplugin.so
	local i
	SM || for i in "${D}${MOZILLA_FIVE_HOME}"/plugins/*; do
		rename "${i##*/}" "${PN}-${i##*/}" "${i}"
	done
	dodir /usr/$(get_libdir)/nsbrowser
	mv "${D}"/usr/$(get_libdir)/{${PN},nsbrowser}/plugins
	dosym ../nsbrowser/plugins "${MOZILLA_FIVE_HOME}"/plugins

	# Add StartupNotify=true bug 237317
	use startup-notification &&
		echo "StartupNotify=true" >> "${D}"/usr/share/applications/${PN}-${DESKTOP_PV}.desktop
}

pkg_preinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	# Remove entire installed instance to solve various problems,
	# for example see bug 27719
#	rm -rf "${ROOT}"${MOZILLA_FIVE_HOME}
}

pkg_postinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	# Update mimedb for the new .desktop file 
	fdo-mime_desktop_database_update
}

langs(){
	local l
	for l in ${LINGUAS} ; do
		use "linguas_${l}" || continue
		l="${l/_/-}"
		case ${l} in
		en|en-US) echo "en-US" ;;
		*) echo "${l}"
		esac
	done
}

SM(){
	[[ "${MY_PN}" == seamonkey ]]
	return $?
}

##########################################################################################
if [[ -n "${hg}" ]]; then

src_unpack() {
	local hg_mod="" d
	use release-branch || use release-tag || local EHG_BRANCH=default
	if [[ "${PVR}" == *-r9999* ]]; then
		[[ "${S}" != "${S1}" ]] && _hg "${S##*/}"
		_hg mozilla-central "${S1}"
	else
		[[ "${S}" != "${S1}" ]] &&  _hg releases/"${S##*/}"
		_hg releases/mozilla-1.9.${PVR##*r} "${S1}"
	fi
	[[ "${MY_PN}" == mobile ]] && _hg mobile-browser "${S}"/mobile
	_hg dom-inspector "${S1}"/extensions/inspector
	_hg schema-validation "${S1}"/extensions/schema-validation xforms
	_hg venkman "${S1}"/extensions/venkman mozdevelop
	_hg pyxpcom "${S1}"/extensions/python python
	_hg chatzilla "${S1}"/extensions/irc !moznoirc
	for i in xforms ipccode; do
		_hg $i "${S1}"/extensions/$i $i
	done
	SM && use !moznomail && use crypt && _git git://git.code.sf.net/p/enigmail/source "${S}"/mailnews/extensions/enigmail enigmail-source
	SM && LDAP && {
		[[ -e "${S}/ldap" ]] && d="${S}/ldap/sdks" || d="${S}/directory"
		EHG_REVISION=LDAPCSDK_6_0_7_RTM _hg projects/ldap-sdks "$d"
	}
	use extra-repo && {
		use moznosystem || use !system-nspr && _cvs_m mozilla/nsprpub "${S1}/nsprpub"
		use moznosystem || use !system-nss && for d in dbm security/nss security/coreconf security/dbm; do
			_cvs_m "mozilla/$d" "${S1}/$d"
		done
#		_cvs_m mozilla/js/src "${S1}/js/src"
#		_cvs_m libffi "${S1}/js/src/ctypes/libffi" "" :pserver:anoncvs@sources.redhat.com:/cvs/libffi
#		ln -s src/libffi "${S1}/js/libffi" # ?
	}
	local l # EHG_EXTRA_OPT="${EHG_EXTRA_OPT} --rev tip"
	mkdir "${WORKDIR}/l10n"
	for l in $(langs) ; do
		[[ "${l}" == "en-US" ]] ||
		if [[ "${PVR}" == *-r9999* ]]; then
			_hg1 l10n-central/${l} "${WORKDIR}/l10n/${l}"
		else
			_hg1 releases/l10n-mozilla-1.9.${PVR##*r}/${l} "${WORKDIR}/l10n/${l}"
		fi
		# remove break if you know how to build multiple locales via source
		break
	done
}

_hg(){
	local hg_src_dir="${PORTAGE_ACTUAL_DISTDIR-${DISTDIR}}/hg-src"
	local m="${hg_mod:-$(basename $1)}"
	if [[ -e "${hg_src_dir}/seamonkey/${m}" ]] && ! [[ -e "${hg_src_dir}/mozilla/${m}" ]]; then
		if [[ -e "${hg_src_dir}/mozilla" ]]; then
			msg="mv ${hg_src_dir}/seamonkey/${m} ${hg_src_dir}/mozilla/${m}"
		else
			msg="mv ${hg_src_dir}/seamonkey ${hg_src_dir}/mozilla"
		fi
		ewarn "Mercurial project repository was renamed. Please, do:"
		ewarn "   $msg"
		die "Rename or delete old project repository: $msg"
	fi

	[[ -n "$3" ]] && ! use $3 && return
	local e="EHG_EXTRA_OPT_${m//-/_}"
	einfo "Hint: use '${e}=\"--date yyyy-mm-dd\"' to day snapshot"
	EHG_PROJECT="mozilla" EHG_EXTRA_OPT="${EHG_EXTRA_OPT} ${!e}" mercurial_fetch "http://hg.mozilla.org/$1" "${m}"
	rm "${WORKDIR}/${m}/.hg" -Rf
	[[ -z "$2" ]] && return
	[[ "`readlink -f $2`" == "${WORKDIR}/${m}" ]] && return
	mkdir -p "$2"
	rm "$2" -Rf
	mv "${WORKDIR}/${m}" "$2"
}

_hg1(){
	hg_mod="${1//\//_}" _hg $*
}

_cvs(){
	[[ -n "$3" ]] && ! use $3 && return
	ECVS_SERVER="mozdev.org:/cvs" \
		ECVS_USER="guest" \
		ECVS_PASS="guest" \
		ECVS_MODULE="$1" \
		cvs_src_unpack
	[[ -z "$2" ]] && return
	[[ "`readlink -f $2`" == "${WORKDIR}/$1" ]] && return
	mkdir -p "$2"
	rm "$2" -Rf
	mv "${WORKDIR}/$1" "$2"
}

_cvs_m(){
	[[ -n "$3" ]] && ! use $3 && return
	ECVS_SERVER="${4:-cvs-mirror.mozilla.org:/cvsroot}" \
		ECVS_MODULE="$1" \
		cvs_src_unpack
	[[ -z "$2" ]] && return
	[[ "`readlink -f $2`" == "${WORKDIR}/$1" ]] && return
	mkdir -p "$2"
	rm "$2" -Rf
	mv "${WORKDIR}/$1" "$2"
}

_git(){
	mkdir -p "$2"
	rm "$2" -Rf
	EGIT_REPO_URI="$1" \
		EGIT_PROJECT="$3" \
		EGIT_SOURCEDIR="$2" \
		git-r3_src_unpack
}

fi

EAPI="2"
WANT_AUTOCONF="2.1"


hg=""
[[ "${PV}" == 9999* ]] && hg="mercurial cvs"
inherit ${hg} flag-o-matic toolchain-funcs eutils mozcoreconf-2 mozconfig-3 makeedit multilib autotools mozextension fdo-mime java-pkg-opt-2 python

: ${FILESDIR:=${EBUILD%/*}/files}

MY_PV="${PV/_rc/rc}"
MY_P="${PN}-${MY_PV}"
EMVER="1.0.1"
PATCH="${PN}-2.0.3-patches-0.1"
MOZVER="1.9.1"

# empty: from hg
LANGS="en be ca cs de es_AR es_ES fr gl hu it ja ka lt nb_NO nl pl pt_PT ru sk sv_SE tr"

#RESTRICT="nomirror"

DESCRIPTION="Mozilla Application Suite - web browser, email, HTML editor, IRC"
HOMEPAGE="http://www.seamonkey-project.org/"
SRC_URI="http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}/source/${MY_P}.source.tar.bz2
	crypt? ( !moznomail? ( http://dev.gentoo.org/~anarchy/dist/enigmail-${EMVER}.tar.gz ) )
	xforms? ( http://hg.mozilla.org/schema-validation/archive/710191b42011.tar.bz2 -> schema-validation-710191b42011.tar.bz2
		http://hg.mozilla.org/xforms/archive/3478e987965d.tar.bz2 -> xforms-3478e987965d.tar.bz2 )"

KEYWORDS="amd64 x86"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="java ldap mozdevelop moznocompose moznoirc moznomail moznoroaming postgres crypt restrict-javascript startup-notification
	debug minimal directfb moznosystem +threads jssh wifi python mobile moznocalendar static
	moznomemory accessibility system-sqlite vanilla xforms gio +alsa
	custom-cflags"
#	qt-experimental"

RDEPEND="java? ( >=virtual/jre-1.4 )
	python? ( >=dev-lang/python-2.3 )
	>=sys-devel/binutils-2.16.1
	!moznosystem? (
		>=dev-libs/nss-3.12.2
		>=dev-libs/nspr-4.7.3
		!static? ( >=app-text/hunspell-1.2 )
		system-sqlite? ( dev-db/sqlite[fts3,secure-delete] )
		>=media-libs/lcms-1.17
		app-arch/bzip2
		x11-libs/cairo[X]
		x11-libs/pango[X]
	)
	alsa? ( media-libs/alsa-lib )
	directfb? ( dev-libs/DirectFB )
	gnome? ( !gio? ( >=gnome-base/gnome-vfs-2.3.5 )
		>=gnome-base/libgnomeui-2.2.0 )
	crypt? ( !moznomail? ( >=app-crypt/gnupg-1.4 ) )"

PDEPEND="restrict-javascript? ( x11-plugins/noscript )"

# wireless-tools requred by future (mercurial repo), maybe now too
DEPEND="java? ( >=virtual/jdk-1.4 )
	${RDEPEND}
       qt-experimental? (
               x11-libs/qt-gui
               x11-libs/qt-core )
	wifi? ( net-wireless/wireless-tools )
	dev-lang/perl
	dev-util/pkgconfig
	postgres? ( >=virtual/postgresql-server-7.2.0 )"

S="${WORKDIR}/comm-${MOZVER}"

ll="${MOZVER}"
if [[ -n "${hg}" ]]; then
	LANGS=""
	IUSE="${IUSE// vanilla/ +vanilla} faststart"
	SRC_URI=""
	if [[ "${PVR}" == *-r9999* ]]; then
		S="${WORKDIR}/comm-central"
		ll="central"
	else
		S="${WORKDIR}/comm-${MOZVER}"
		ll="1.9.${PVR##*r}"
	fi
elif [[ -z "${LANGS}" ]]; then
	SRC_URI="${SRC_URI} `sed -e 's:^\(.*\) \(.*\)\$:linguas_\1? ( \2 -> '${MY_P}'.lang.\1.tar.bz2 ):' <${FILESDIR}/${ll}.langs`"
fi

if [[ -z "${LANGS}" ]]; then
	LANGS="en_US $(sed -e 's: .*::g' <"${FILESDIR}/${ll}.langs")"
else
	for l in ${LANGS}; do
		[[ ${l} == "en" ]] || [[ ${l} == "en_US" ]] || SRC_URI="${SRC_URI} linguas_${l}? ( http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}/langpack/${MY_P}.${l/_/-}.langpack.xpi -> ${MY_P}-${l/_/-}.xpi )"
	done
fi

for l in ${LANGS}; do
	IUSE="${IUSE} linguas_${l}"
done

#[[ -n "${PATCH}" ]] && SRC_URI="${SRC_URI}  !vanilla? ( mirror://gentoo/${PATCH}.tar.bz2 )"
#[[ -n "${PATCH}" ]] && SRC_URI="${SRC_URI}  !vanilla? ( http://dev.gentoo.org/~anarchy/dist/${PATCH}.tar.bz2 )"
[[ -n "${PATCH}" ]] && SRC_URI="${SRC_URI}  !vanilla? ( http://dev.gentoo.org/~polynomial-c/${PATCH}.tar.bz2 )"

S1="${S}/mozilla"


# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
export MOZ_CO_PROJECT=suite
export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1
export PERL="/usr/bin/perl"

src_unpack() {
	use static && use jssh && die 'Useflags "static" & "jssh" incompatible'
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
	java-pkg-opt-2_src_prepare

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

	if [[ -e "${WORKDIR}"/enigmail ]]; then
		mv "${WORKDIR}"/enigmail "${S}"/mailnews/extensions/enigmail
	fi

	if [[ -e "${S}"/mailnews/extensions/enigmail ]]; then
		cd "${S}"/mailnews/extensions/enigmail || die
		makemake2
	fi

	mv "${WORKDIR}"/xforms* "${S1}"/extensions/xforms
	mv "${WORKDIR}"/schema-validation* "${S1}"/extensions/schema-validation

	# Fix scripts that call for /usr/local/bin/perl #51916
	ebegin "Patching smime to call perl from /usr/bin"
	sed -i -e '1s,usr/local/bin/perl,usr/bin/perl,' "${S1}"/security/nss/cmd/smimetools/smime
	eend $? || die "sed failed"

	ebegin "Other misc. patches"
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
	eend $? || die "sed failed"

	for i in "${S1}/js/src" "${S1}" "${S}" ; do
		cd "${i}"
		eautoreconf
	done
}

src_configure(){
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	local o3=false
	setup-allowed-flags
	if use custom-cflags; then
		is-flag -O3 && o3=true
		export ALLOWED_FLAGS="${ALLOWED_FLAGS} ${CFLAGS}"
	else
		export ALLOWED_FLAGS="${ALLOWED_FLAGS} -fomit-frame-pointer -O3 -mfpmath -msse* -m3dnow* -mmmx -mstackrealign"
	fi

	mozconfig_init
	mozconfig_config

	rmopt --with-system-png

	use alpha && append-ldflags "-Wl,--no-relax"

	###### --disable-pango work in seamonkey-1.1.14, but broken here
#	if use moznopango; then
#		rmopt able-pango
#		mozconfig_annotate -pango \
#			--disable-pango
#	fi

        if use vanilla; then
	if use directfb; then
		if ! built_with_use x11-libs/cairo directfb; then
>			eerror "Cairo must be build with same state of 'directfb' useflag"
			eerror "Please add 'directfb' to your USE flags, and re-emerge cairo."
			die "Cairo needs directfb"
		fi
	elif built_with_use x11-libs/cairo directfb; then
		ewarn "Cairo built with 'directfb' useflag, but seamonkey with '-directfb':"
		ewarn "using built-in Cairo instead..."
		rmopt -system-cairo
		mozconfig_annotate "-directfb, cairo ${x1}DirectFB surface" --disable-system-cairo
	fi
	fi

	mozconfig_annotate 'gentoo' \
		--with-system-bz2 \
		--enable-canvas \
		--with-system-nspr \
		--with-system-nss \
		--enable-image-encoder=all \
		--enable-system-lcms \
		--with-default-mozilla-five-home=${MOZILLA_FIVE_HOME} \
		--with-user-appdir=.mozilla \
		--without-system-png \
		--enable-pref-extensions \
		--disable-tests

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

	# I don't know about sqlite bugs (runtime segfaults on x86_64 unknown source, testing),
	# but internal sqlite are monolythic (must be faster)
	mozconfig_use_enable system-sqlite

	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks

	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate 'galeon' --enable-oji --enable-mathml

	# Other moz-specific settings
	mozconfig_use_enable mozdevelop jsd
	mozconfig_use_enable mozdevelop xpctools
	if [[ -z "${hg}" ]] || [[ "${PVR}" == *r1 ]]; then
		mozconfig_use_extension python python/xpcom
	else
		# XULRunner>=1.9.2
		mozconfig_use_extension python python
	fi
	mozconfig_use_enable java javaxpcom
	mozconfig_use_extension jssh jssh
#	mozconfig_use_extension widgetutils widgetutils
	mozconfig_use_extension mozdevelop venkman
	mozconfig_use_extension mozdevelop layout-debug
#	mozconfig_use_extension accessibility access-builtin
	mozconfig_use_enable wifi necko-wifi
	mozconfig_use_enable ldap
	mozconfig_use_enable ldap ldap-experimental
	mozconfig_use_with threads pthreads
	mozconfig_use_enable mobile mobile-optimize
	mozconfig_use_enable !moznocalendar calendar
	mozconfig_use_enable static
	mozconfig_use_enable static static-mail
#	mozconfig_use_enable static js-static-build
	mozconfig_use_enable !static system-hunspell
	if use threads ; then
		mozconfig_use_enable !moznomemory jemalloc
	else
		mozconfig_annotate "-threads" --disable-jemalloc
		ewarn "jemalloc do not support -threads, disabling jemalloc"
	fi
	mozconfig_use_enable accessibility
	# ignored in 2.0
	mozconfig_use_enable gio
	mozconfig_use_enable faststart
	mozconfig_use_enable alsa ogg
	mozconfig_use_enable alsa wave

	if use moznoirc; then
		mozconfig_annotate '+moznocompose +moznoirc' --enable-extensions=-irc
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

	if use minimal; then
#		use mobile && mozconfig_annotate +minimal,+mobile
#			--with-embedding-profile=minimal
		mozconfig_annotate +minimal \
			--disable-postscript \
			--disable-help-viewer \
			--disable-safe-browsing \
			--disable-url-classifier \
			--enable-necko-small-buffers \
			--disable-parental-controls
	else
		mozconfig_annotate -minimal \
			--enable-postscript \
			--enable-help-viewer \
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

	$o3 && sed -i -e 's:\=\-O2:=-O3:g' .mozconfig

	# required for sse prior to gcc 4.4.3, may be faster in other cases
	[[ "${ARCH}" == "x86" ]] && append-flags -mstackrealign

	if use qt-experimental ; then
		sed -i -e 's%--enable-default-toolkit=cairo-gtk2%--enable-default-toolkit=cairo-qt%g' "${S}"/.mozconfig
		rmopt -system-cairo
		mozconfig_annotate "qt-experimental" --disable-system-cairo
	fi

	use moznosystem &&
	    einfo "USE 'moznosystem' flag - disabling usage system libs" &&
	    sed -i -e 's/--enable-system-/--disable-system-/g' -e 's/--with-system-/--without-system-/g' "${S}"/.mozconfig

	# Finalize and report settings
	mozconfig_final

	if [[ $(gcc-major-version) -lt 4 ]]; then
		append-cxxflags -fno-stack-protector
	fi

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
	econf || die
#	emake -f client.mk configure CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" || die

	if use directfb && use vanilla; then
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

src_compile() {
	# sometimes parallel build breaks
	emake || emake -j1 || die
	if use crypt && ! use moznomail; then
		emake -C "${S}"/mailnews/extensions/enigmail || die
	fi
}

rmopt(){
	sed -i -e "/$*/d" "${S}"/.mozconfig
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

	# Most of the installation happens here
	dodir "${MOZILLA_FIVE_HOME}"
	cp -RL "${S1}"/dist/bin/* "${D}"/"${MOZILLA_FIVE_HOME}"/ || die "cp failed"

	if [[ -n ${LANG} && ${LANG} != "en-US" ]]; then
		elog "Setting default locale to ${LANG}"
		dosed -e "s:\"en-US\":\"${LANG}\":g" \
			"${MOZILLA_FIVE_HOME}"/defaults/pref/suite-l10n.js ||
			die "sed failed to change locale"
	fi

	# Create directory structure to support portage-installed extensions.
	# See update_chrome() in mozilla-launcher
	keepdir ${MOZILLA_FIVE_HOME}/chrome.d
	keepdir ${MOZILLA_FIVE_HOME}/extensions.d
	cp "${D}"${MOZILLA_FIVE_HOME}/chrome/installed-chrome.txt \
		"${D}"${MOZILLA_FIVE_HOME}/chrome.d/0_base-chrome.txt

	# Install icon and .desktop for menu entry
	newicon "${S}"/suite/branding/content/icon64.png seamonkey.png
	domenu "${FILESDIR}"/icon/${PN}.desktop

	# Create /usr/bin/seamonkey
	make_wrapper seamonkey "${MOZILLA_FIVE_HOME}/seamonkey"

	# prevent to stalled terminal outputs
	exeinto /usr/bin
	doexe "${FILESDIR}"/seamonkey-X

	# Add vendor
	echo "pref(\"general.useragent.vendor\",\"Gentoo\");" >> "${D}"${MOZILLA_FIVE_HOME}/defaults/pref/vendor.js

	# Install rebuild script since mozilla-bin doesn't support registration yet
	exeinto ${MOZILLA_FIVE_HOME}
	doexe "${FILESDIR}"/${PN}-rebuild-databases.pl
	dosed -e 's|/lib/|/'"$(get_libdir)"'/|g' \
		${MOZILLA_FIVE_HOME}/${PN}-rebuild-databases.pl

	# Install docs
	dodoc "${S1}"/{LEGAL,LICENSE}

	dodir /usr/$(get_libdir)/nsbrowser
	mv "${D}"/usr/$(get_libdir)/{$PN,nsbrowser}/plugins
	dosym ../nsbrowser/plugins /usr/$(get_libdir)/$PN/plugins

	# Add StartupNotify=true bug 237317
	use startup-notification &&
		echo "StartupNotify=true" >> "${D}"/usr/share/applications/${PN}-${DESKTOP_PV}.desktop

}

pkg_preinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	# Remove entire installed instance to solve various problems,
	# for example see bug 27719
	rm -rf "${ROOT}"${MOZILLA_FIVE_HOME}
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

##########################################################################################
if [[ -n "${hg}" ]]; then

src_unpack() {
	use static && use jssh && die 'Useflags "static" & "jssh" incompatible'
	local hg_mod=""
	if [[ "${PVR}" == *-r9999* ]]; then
		_hg comm-central
		_hg mozilla-central "${S1}"
	else
		_hg releases/comm-${MOZVER}
		_hg releases/mozilla-1.9.${PVR##*r} "${S1}"
	fi
	_hg dom-inspector "${S1}"/extensions/inspector
	_hg xforms "${S1}"/extensions/xforms xforms
	_hg schema-validation "${S1}"/extensions/schema-validation xforms
	_hg venkman "${S1}"/extensions/venkman mozdevelop
	_hg pyxpcom "${S1}"/extensions/python python
	use !moznoirc && _hg chatzilla "${S1}"/extensions/irc
	use !moznomail && use crypt && _cvs enigmail/src "${S}"/mailnews/extensions/enigmail crypt
	#use !moznoirc && _cvs_m "mozilla/extensions/irc" "${S1}/extensions/irc"
	ECVS_BRANCH="LDAPCSDK_6_0_6_RTM" _cvs_m mozilla/directory/c-sdk "${S}/directory/c-sdk" ldap
	local l
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

	[[ -n "$3" ]] && use !"$3" && return
	EHG_PROJECT="mozilla" mercurial_fetch "http://hg.mozilla.org/$1" "${m}"
	rm "${WORKDIR}/${m}/.hg" -Rf
	[[ -z "$2" ]] && return
	[[ -e "$2" ]] && rm "$2" -Rf
	mv "${WORKDIR}/${m}" "$2"
}

_hg1(){
	hg_mod="${1//\//_}" _hg $*
}

_cvs(){
	[[ -n "$3" ]] && use !"$3" && return
	ECVS_SERVER="mozdev.org:/cvs" \
		ECVS_USER="guest" \
		ECVS_PASS="guest" \
		ECVS_MODULE="$1" \
		cvs_src_unpack
	[[ -z "$2" ]] && return
	[[ -e "$2" ]] && rm "$2" -Rf
	mv "${WORKDIR}/$1" "$2"
}

_cvs_m(){
	[[ -n "$3" ]] && use !"$3" && return
	ECVS_SERVER="cvs-mirror.mozilla.org:/cvsroot" \
		ECVS_MODULE="$1" \
		cvs_src_unpack
	[[ -z "$2" ]] && return
	[[ -e "$2" ]] && rm "$2" -Rf
	mv "${WORKDIR}/$1" "$2"
}

fi

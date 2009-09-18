
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozcoreconf-2 mozconfig-3 makeedit multilib autotools mozextension fdo-mime java-pkg-opt-2 python

MY_PV="${PV/_beta/b}"
MY_P="${PN}-${MY_PV}"
EMVER="0.96.0"
LANGS="en be ca cs de es_AR es_ES fr gl hu lt nb_NO pl pt_PT ru sk tr"
PATCH=""

RESTRICT="nomirror"

DESCRIPTION="Mozilla Application Suite - web browser, email, HTML editor, IRC"
HOMEPAGE="http://www.seamonkey-project.org/"
SRC_URI="http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}/source/${MY_P}-source.tar.bz2
	crypt? ( !moznomail? (
		http://www.mozilla-enigmail.org/download/source/enigmail-${EMVER}.tar.gz
	) )"

[[ "${PATCH}" != "" ]] && SRC_URI="${SRC_URI}  mirror://gentoo/${PATCH}.tar.bz2"

KEYWORDS="amd64 x86"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="java ldap mozdevelop moznocompose moznoirc moznomail moznoroaming postgres crypt restrict-javascript startup-notification
	debug minimal directfb moznosystem threads jssh wifi python mobile moznocalendar static
	moznomemory accessibility"
#	qt-experimental"
[[ "${ARCH}" == "x86" ]] && IUSE="${IUSE} sse"

RDEPEND="java? ( >=virtual/jre-1.4 )
	python? ( >=dev-lang/python-2.3 )
	>=sys-devel/binutils-2.16.1
	!moznosystem? (
		>=dev-libs/nss-3.12.2
		>=dev-libs/nspr-4.7.3
		!static? ( >=app-text/hunspell-1.2 )
		>=dev-db/sqlite-3.6.7
		>=media-libs/lcms-1.17
		app-arch/bzip2
	)
	directfb? ( dev-libs/DirectFB )
	gnome? ( >=gnome-base/gnome-vfs-2.3.5
		>>=gnome-base/libgnomeui-2.2.0 )
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


S="${WORKDIR}/comm-central"
S1="${S}/mozilla"

for l in ${LANGS}; do
	IUSE="${IUSE} linguas_${l}"
	[[ ${l} == "en" ]] || SRC_URI="${SRC_URI} linguas_${l}? ( http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}/langpack/${MY_P}.${l/_/-}.langpack.xpi )"
done

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
export MOZ_CO_PROJECT=suite
export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1
export PERL="/usr/bin/perl"

src_unpack() {
	local i
	# do not use pkg_setup to not care about eclasses
	use moznosystem || for i in x11-libs/cairo x11-libs/pango ; do
		if ! built_with_use --missing true ${i} X; then
			eerror "${i} is not built with X useflag."
			eerror "Please add 'X' to your USE flags, and re-emerge ${i}."
			die "${i} needs X"
		fi
	done
	use static && use jssh &&
		die 'Useflags "static" & "jssh" incompatible'

	unpack ${MY_P}-source.tar.bz2

	for l in ${LINGUAS}; do
		if use "linguas_${l}" && [[ ${l} != "en" ]] ; then
			xpi_unpack "${MY_P}.${l/_/-}.langpack.xpi"
		fi
	done
	cd "${S}"

	if [[ "${PATCH}" != "" ]]; then
		unpack ${PATCH}.tar.bz2
		rm "${WORKDIR}"/patch/{*noxul,*xulonly,005,030,096,667,085}*
		#rm "${WORKDIR}"/patch/{007,009,020,021,064,097,300,030,096,667,085}*
		cd "${S1}" || die "cd failed"
		EPATCH_SUFFIX="patch" \
			EPATCH_FORCE="yes" \
			epatch "${WORKDIR}"/patch
	fi

	cd "${S}"
	[[ -e "${FILESDIR}/${PV}" ]] &&
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${FILESDIR}"/${PV}

	# Unpack the enigmail plugin
	if use crypt && ! use moznomail; then
		cd "${S}"/mailnews/extensions || die
		unpack enigmail-${EMVER}.tar.gz
		cd "${S}"
		[[ -e "${FILESDIR}/em-${EMVER}" ]] &&
		    EPATCH_SUFFIX="patch" \
		    EPATCH_FORCE="yes" \
		    epatch "${FILESDIR}/em-${EMVER}"
#		cd "${S}"/mailnews/extensions/enigmail/lang || die
#		for l in ${LANGS} ; do
#			[[ -d "${l}" ]] && continue
#			local ll=`echo ${l}-*`
#			[[ -d "${ll}" ]] || continue
#			einfo "Renaming enigmail locale '${ll}' to '${l}'"
#			rename "${ll}" "${l}" "${ll}" || die
#			sed -i -e "s:${ll}:${l}:g" "${l}"/contents.rdf current-languages.txt
#		done
#		for l in ${LANGS} ; do
#			use "linguas_${l}" || continue
#			cd "${S}"/mailnews/extensions/enigmail/lang/${l} || continue
#			einfo "Making enigmail locale: $l"
#			../make-lang.sh ${l} ${EMVER}
#			local f="${S}/mailnews/extensions/enigmail/lang/${l}/enigmail-${l}-${EMVER}.xpi"
#			[[ -e "${f}" ]] || continue
#			xpi_unpack "${f}"
#			cd "${S}"/mailnews/extensions/enigmail/lang
#			sed -i -e "/${l}$/d" "${S}/mailnews/extensions/enigmail/lang/current-languages.txt"
#		done
		cd "${S}"/mailnews/extensions/enigmail || die
		makemake2
	fi

	# Fix scripts that call for /usr/local/bin/perl #51916
	ebegin "Patching smime to call perl from /usr/bin"
	sed -i -e '1s,usr/local/bin/perl,usr/bin/perl,' "${S1}"/security/nss/cmd/smimetools/smime
	eend $? || die "sed failed"

	ebegin "Other misc. patches"
	## gentoo install dirs
	sed -i -e 's%-$.MOZ_APP_VERSION.$%%g' "${S}"/config/autoconf.mk.in

	sed -i -e 's%^#elif$%#elif 1%g' "${S1}"/toolkit/xre/nsAppRunner.cpp
	eend $? || die "sed failed"

	for i in "${S}" ; do
		cd "${i}"
		eautoreconf
	done
}

src_compile() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	local i
	local o3=false
	local omitfp=false

	# good for suite / integrated xulrunner
	is-flag -O3 && o3=true
	is-flag -fomit-frame-pointer && omitfp=true

	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################
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

	mozconfig_annotate 'gentoo' \
		--with-system-bz2 \
		--enable-canvas \
		--with-system-nspr \
		--with-system-nss \
		--enable-image-encoder=all \
		--enable-system-lcms \
		--enable-system-sqlite \
		--with-default-mozilla-five-home=${MOZILLA_FIVE_HOME} \
		--with-user-appdir=.mozilla \
		--without-system-png \
		--enable-pref-extensions \
		--disable-tests

	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks

	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate 'galeon' --enable-oji --enable-mathml

	# Other moz-specific settings
	mozconfig_use_enable mozdevelop jsd
	mozconfig_use_enable mozdevelop xpctools
	mozconfig_use_extension python python/xpcom
	mozconfig_use_enable java javaxpcom
	mozconfig_use_extension jssh jssh
#	mozconfig_use_extension widgetutils widgetutils
	mozconfig_use_extension mozdevelop venkman
	mozconfig_use_extension mozdevelop layout-debug
	mozconfig_use_extension accessibility
#	mozconfig_use_extension accessibility access-builtin
	mozconfig_use_enable wifi necko-wifi
	mozconfig_use_enable ldap
	mozconfig_use_enable ldap ldap-experimental
	mozconfig_use_with threads pthreads
	mozconfig_use_enable mobile mobile-optimize
	mozconfig_use_enable !moznocalendar calendar
	mozconfig_use_enable static
#	mozconfig_use_enable static js-static-build
	mozconfig_use_enable !static system-hunspell
	mozconfig_use_enable !moznomemory jemalloc

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

	# use xforms && mozconfig_annotate "+xforms" --enable-extensions=xforms,schema-validation

	if use minimal; then
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
	$omitfp && use !debug && append-flags -fomit-frame-pointer
	if [[ "${ARCH}" == "x86" ]] && [[ $(gcc-major-version).$(gcc-minor-version) == 4.4 ]] ; then
		if use sse ; then
			append-flags -msse -mstackrealign
		else
			append-flags -mno-sse
		fi
	fi

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

	####################################
	#
	#  Configure and build
	#
	####################################

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
	econf || die
	# cross-compile problem:
#	emake -f client.mk configure CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" || die

	if use directfb; then
		local dl=`pkg-config directfb --libs`
#		local dl="-ldirectfb -ldirect"
		sed -i -e 's%\(^MOZ_DFB.*\)%\1 1%' \
			-e 's%\(^OS_LIBS.*\)%\1 '"${dl}"'%' \
			"${S1}"/config/autoconf.mk
	fi

	# This removes extraneous CFLAGS from the Makefiles to reduce RAM
	# requirements while compiling
	edit_makefiles

	# sometimes parallel build breaks
	emake || emake -j1 || die

	####################################
	#
	#  Build Enigmail extension
	#
	####################################

	if use crypt && ! use moznomail; then
		emake -C "${S}"/mailnews/extensions/enigmail || die "make enigmail failed"

	fi
}

rmopt(){
	sed -i -e "/$*/d" "${S}"/.mozconfig
}

src_install() {
	declare MOZILLA_FIVE_HOME=/usr/$(get_libdir)/${PN}

	local LANG=""
	local d
	for l in ${LINGUAS}; do
		use "linguas_${l}" || continue
		l=${l/_/-}
		LANG=${LANG:=${l}}
		for d in "${WORKDIR}/${MY_P}.${l}.langpack" "${WORKDIR}/enigmail-${l}-${EMVER}" ; do
			[[ -e "${d}" ]] && xpi_install "${d}"
		done
	done

	# Most of the installation happens here
	dodir "${MOZILLA_FIVE_HOME}"
	cp -RL "${S1}"/dist/bin/* "${D}"/"${MOZILLA_FIVE_HOME}"/ || die "cp failed"

	if [[ -n ${LANG} && ${LANG} != "en" ]]; then
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

	ewarn "This is beta version of Seamonkey-2 and if you are"
	ewarn "have problems with exporting preferences from Seamonkey-1 -"
	ewarn "just copy by hands requred files (prefs.js, ...)"
	ewarn "from ~/.mozilla/default/<profile>/ to ~/.mozilla/seamonkey/<profile>/"
}

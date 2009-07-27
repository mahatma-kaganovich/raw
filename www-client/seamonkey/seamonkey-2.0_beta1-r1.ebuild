
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozcoreconf-2 mozconfig-3 makeedit multilib autotools mozextension fdo-mime java-pkg-opt-2 python

MY_PV="${PV/_beta/b}"
MY_P="${PN}-${MY_PV}"
EMVER="0.96.0"
LANGS="en be ca cs de es_AR es_ES fr gl hu lt nb_NO pl pt_PT ru sk tr"

RESTRICT="nomirror"

DESCRIPTION="Mozilla Application Suite - web browser, email, HTML editor, IRC"
HOMEPAGE="http://www.seamonkey-project.org/"
SRC_URI="http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}/source/${MY_P}-source.tar.bz2
	crypt? ( !moznomail? (
		http://www.mozilla-enigmail.org/download/source/enigmail-${EMVER}.tar.gz
	) )"

[[ "${PATCH}" != "" ]] && SRC_URI="${SRC_URI}  mirror://gentoo/${PATCH}.tar.bz2"

KEYWORDS="~amd64 ~x86"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="java ldap mozdevelop moznocompose moznoirc moznomail moznoroaming postgres crypt restrict-javascript
	debug minimal directfb moznosystem threads jssh wifi python mobile"

RDEPEND="java? ( >=virtual/jre-1.4 )
	python? ( >=dev-lang/python-2.3 )
	>=sys-devel/binutils-2.16.1
	!moznosystem? (
		>=dev-libs/nss-3.12.2
		>=dev-libs/nspr-4.7.3
		>=app-text/hunspell-1.2
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
		cd "${S}"/mailnews/extensions/enigmail/lang || die "cd failed"
		for l in ${LANGS} ; do
			[[ -d "${l}" ]] && continue
			local ll=`echo ${l}-*`
			[[ -d "${ll}" ]] || continue
			einfo "Renaming enigmail locale '${ll}' to '${l}'"
			rename "${ll}" "${l}" "${ll}" || die
			sed -i -e 's%:'"${ll}"'\([:"]\)%:'"${l}"'\1%g' "${l}"/contents.rdf #"
		done
		cd "${S}"/mailnews/extensions/enigmail
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

	cd "${S}"
	eautoreconf
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
#		rmopt tree-freetype
#		mozconfig_annotate -pango \
#			--enable-tree-freetype \
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
		--enable-calendar \
		--enable-canvas \
		--with-system-nspr \
		--with-system-nss \
		--enable-image-encoder=all \
		--enable-system-lcms \
		--enable-system-sqlite \
		--with-default-mozilla-five-home=${MOZILLA_FIVE_HOME} \
		--with-user-appdir=.mozilla \
		--enable-system-hunspell \
		--without-system-png \
		--enable-pref-extensions \
		--disable-tests

	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks

	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate 'galeon' --enable-oji --enable-mathml

	# Other moz-specific settings
#	mozconfig_use_enable truetype tree-freetype
	mozconfig_use_enable mozdevelop jsd
	mozconfig_use_enable mozdevelop xpctools
	mozconfig_use_extension python python/xpcom
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
			--disable-parental-controls
	else
		mozconfig_annotate -minimal \
			--enable-postscript \
			--enable-help-viewer \
			--enable-safe-browsing \
			--enable-url-classifier \
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

	#sed -i -e 's%--enable-default-toolkit=cairo-gtk2%--enable-default-toolkit=cairo-qt%g' "${S}"/.mozconfig

	use moznosystem &&
	    einfo "USE 'moznosystem' flag - disabling usage system libs" &&
	    sed -i -e 's/--enable-system-/--disable-system-/g' -e 's/--with-system-/--without-system-/g' "${S}"/.mozconfig

	# Finalize and report settings
	mozconfig_final

	# -fstack-protector breaks us
	if gcc-version ge 4 1; then
		gcc-specs-ssp && append-flags -fno-stack-protector
	else
		gcc-specs-ssp && append-flags -fno-stack-protector-all
	fi
		filter-flags -fstack-protector -fstack-protector-all

	####################################
	#
	#  Configure and build
	#
	####################################

	JAVA_HOME="${JAVA_HOME}" \
	CPPFLAGS="${CPPFLAGS} -DARON_WAS_HERE" \
	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
	econf || die

	if use directfb; then
		#local dl=`pkg-config directfb --libs`
		local dl="-ldirectfb -ldirect"
		sed -i -e 's%\(^MOZ_DFB.*\)%\1 1%' \
			-e 's%\(^OS_LIBS.*\)%\1 '"${dl}"'%' \
			"${S1}"/config/autoconf.mk
	fi

	# It would be great if we could pass these in via CPPFLAGS or CFLAGS prior
	# to econf, but the quotes cause configure to fail.
	sed -i -e \
		's|-DARON_WAS_HERE|-DGENTOO_NSPLUGINS_DIR=\\\"/usr/'"$(get_libdir)"'/nsplugins\\\" -DGENTOO_NSBROWSER_PLUGINS_DIR=\\\"/usr/'"$(get_libdir)"'/nsbrowser/plugins\\\"|' \
		"${S}"/config/autoconf.mk \
		"${S1}"/config/autoconf.mk \
		"${S1}"/xpfe/global/buildconfig.html

	# This removes extraneous CFLAGS from the Makefiles to reduce RAM
	# requirements while compiling
	edit_makefiles

	emake || die "Emake failed. Before panic - just try to repeat emerge command."

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
	for l in ${LINGUAS}; do
		use "linguas_${l}" || continue
		l=${l/_/-}
		LANG=${LANG:=${l}}
		[[ ${l} == "en" ]] && continue
		xpi_install "${WORKDIR}/${MY_P}.${l}.langpack"
		! use crypt && continue
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

	ln -s ${D}/usr/$(get_libdir)/nsbrowser/plugins ${D}/usr/$(get_libdir)/${PN}/plugins

	# Install rebuild script since mozilla-bin doesn't support registration yet
	exeinto ${MOZILLA_FIVE_HOME}
	doexe "${FILESDIR}"/${PN}-rebuild-databases.pl
	dosed -e 's|/lib/|/'"$(get_libdir)"'/|g' \
		${MOZILLA_FIVE_HOME}/${PN}-rebuild-databases.pl

	# Install docs
	dodoc "${S1}"/{LEGAL,LICENSE}
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

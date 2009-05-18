
WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozcoreconf-2 mozconfig-3 mozilla-launcher makeedit multilib autotools mozextension

MY_PV="${PV/_alpha/a}"
MY_P="${PN}-${MY_PV}"
PATCH="mozilla-firefox-3.0.10-patches-0.1"
EMVER="0.95.7"
EMPATCH="enigmail-${EMVER}-cvs-20090317"
LANGS="en ca cs de es_AR es_ES fr lt nb_NO nl pl pt_BR ru sk"

RESTRICT="nomirror"

DESCRIPTION="Mozilla Application Suite - web browser, email, HTML editor, IRC"
HOMEPAGE="http://www.seamonkey-project.org/"
SRC_URI="http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}/source/${MY_P}.source.tar.bz2
	crypt? ( !moznomail? (
		http://www.mozilla-enigmail.org/download/source/enigmail-${EMVER}.tar.gz
		http://mahatma.bspu.unibel.by/download/transit/${EMPATCH}.tar.bz2
	) )"

[[ "${PATCH}" != "" ]] && SRC_URI="${SRC_URI}  mirror://gentoo/${PATCH}.tar.bz2"

KEYWORDS="amd64 x86 ppc"
SLOT="0"
LICENSE="|| ( MPL-1.1 GPL-2 LGPL-2.1 )"
IUSE="java ldap mozdevelop moznocompose moznoirc moznomail moznoroaming postgres crypt minimal moznopango restrict-javascript directfb moznosystem"

RDEPEND="java? ( virtual/jre )
	!moznosystem? (
		>=www-client/mozilla-launcher-1.56
		>=dev-libs/nss-3.11.5
		>=dev-libs/nspr-4.6.5-r1
		app-text/hunspell
		>=media-libs/lcms-1.17 )
	directfb? ( dev-libs/DirectFB )
	gnome? ( >=gnome-base/gnome-vfs-2.3.5
		>>=gnome-base/libgnomeui-2.2.0 )
	crypt? ( !moznomail? ( >=app-crypt/gnupg-1.4 ) )"
# broken
# 		dev-db/sqlite

DEPEND="${RDEPEND}
	java? ( >=dev-java/java-config-0.2.0 )
	dev-lang/perl
	postgres? ( >=virtual/postgresql-server-7.2.0 )"

PDEPEND="restrict-javascript? ( x11-plugins/noscript )"

S="${WORKDIR}"
S1="${WORKDIR}/mozilla"

for l in ${LANGS}; do
	IUSE="${IUSE} linguas_${l}"
	[[ ${l} == "en" ]] && continue
	SRC_URI="${SRC_URI} linguas_${l}? ( http://releases.mozilla.org/pub/mozilla.org/${PN}/releases/${MY_PV}/langpack/${MY_P}.${l/_/-}.langpack.xpi )"
done

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
export MOZ_CO_PROJECT=suite
export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1
export PERL="/usr/bin/perl"

pkg_setup() {
	use moznopango && warn_mozilla_launcher_stub
}

src_unpack() {
	unpack ${MY_P}.source.tar.bz2

	for l in ${LINGUAS}; do
		use "linguas_${l}" && [[ ${l} != "en" ]] && xpi_unpack "${MY_P}.${l/_/-}.langpack.xpi"
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
	[[ -e "${FILESDIR}"/${PV} ]] &&
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
	epatch "${FILESDIR}"/${PV}

	# Unpack the enigmail plugin
	if use crypt && ! use moznomail; then
		cd "${S}"/mailnews/extensions || die
		unpack enigmail-${EMVER}.tar.gz
		cd "${S}"/mailnews/extensions/enigmail || die "cd failed"
		test ${EMPATCH} && epatch "${DISTDIR}"/${EMPATCH}.tar.bz2
		makemake2
	fi

	# Fix scripts that call for /usr/local/bin/perl #51916
	ebegin "Patching smime to call perl from /usr/bin"
	sed -i -e '1s,usr/local/bin,usr/bin,' "${S1}"/security/nss/cmd/smimetools/smime
	eend $? || die "sed failed"

	sed -i -e 's%^#elif$%#elif 1%g' "${S1}"/toolkit/xre/nsAppRunner.cpp

	cd "${S}"
	eautoreconf
}

src_compile() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

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
#		rmopt -freetype2
#		mozconfig_annotate moznopango freetype2 \
#			--enable-freetype2 \
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
		--enable-calendar \
		--enable-canvas \
		--with-system-nspr \
		--with-system-nss \
		--enable-image-encoder=all \
		--enable-system-lcms \
		--disable-system-sqlite \
		--with-default-mozilla-five-home=${MOZILLA_FIVE_HOME} \
		--with-user-appdir=.mozilla \
		--enable-system-hunspell \
		--without-system-png \
		--disable-tests

	mozconfig_annotate 'places' --enable-storage --enable-places

	# Bug 60668: Galeon doesn't build without oji enabled, so enable it
	# regardless of java setting.
	mozconfig_annotate 'galeon' --enable-oji --enable-mathml

	# Other moz-specific settings
	mozconfig_use_enable mozdevelop jsd
	mozconfig_use_enable mozdevelop xpctools
	mozconfig_use_extension mozdevelop venkman

	mozconfig_use_enable ldap
	mozconfig_use_enable ldap ldap-experimental

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

	#sed -i -e 's%--enable-default-toolkit=cairo-gtk2%--enable-default-toolkit=cairo-qt%g' "${S}"/.mozconfig

	use moznosystem &&
	    einfo "USE 'moznosystem' flag - disabling usage system libs" &&
	    nosys ""

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
	sed -i -e 's%.*'"$*"'.*%%g' "${S}"/.mozconfig
}

nosys(){
	local i
	einfo "disabling system: $*"
	for i in $* ; do
		sed -i -e "s/--enable-system-${i}/--disable-system-${i}/g" -e "s/--with-system-${i}/--without-system-${i}/g" "${S}"/.mozconfig
	done
}

src_install() {
	declare MOZILLA_FIVE_HOME=/usr/$(get_libdir)/${PN}

	local LANG=""
	for l in ${LINGUAS}; do
		use "linguas_${l}" || continue
		LANG=${LANG:=${l}}
		[[ ${l} != "en" ]] && xpi_install "${S}/${MY_P}.${l/_/-}.langpack"
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

	# Create /usr/bin/seamonkey
	install_mozilla_launcher_stub seamonkey ${MOZILLA_FIVE_HOME}

	# Install icon and .desktop for menu entry
	doicon "${FILESDIR}"/icon/${PN}.png
	domenu "${FILESDIR}"/icon/${PN}.desktop

	# Fix icons to look the same everywhere
	insinto ${MOZILLA_FIVE_HOME}/icons
	doins "${S1}"/widget/src/gtk/mozicon16.xpm
	doins "${S1}"/widget/src/gtk/mozicon50.xpm

	####################################
	#
	# Install files necessary for applications to build against seamonkey
	#
	####################################

	einfo "Installing includes and idl files..."
	cp -LfR "${S1}"/dist/include "${D}"/"${MOZILLA_FIVE_HOME}" || die "cp failed"
	cp -LfR "${S1}"/dist/idl "${D}"/"${MOZILLA_FIVE_HOME}" || die "cp failed"

	# Fix mozilla-config and install it
	exeinto ${MOZILLA_FIVE_HOME}
	doexe "${S1}"/build/unix/${PN}-config

	# Install pkgconfig files
	insinto /usr/"$(get_libdir)"/pkgconfig
	doins "${S1}"/build/unix/*.pc

	# Install env.d snippet, which isn't necessary for running mozilla, but
	# might be necessary for programs linked against firefox
	doenvd "${FILESDIR}"/10${PN}
	dosed "s|/usr/lib|/usr/$(get_libdir)|" /etc/env.d/10${PN}

	# Install rebuild script since mozilla-bin doesn't support registration yet
	exeinto ${MOZILLA_FIVE_HOME}
	doexe "${FILESDIR}"/${PN}-rebuild-databases.pl
	dosed -e 's|/lib/|/'"$(get_libdir)"'/|g' \
		${MOZILLA_FIVE_HOME}/${PN}-rebuild-databases.pl

	# Install docs
	dodoc "${S}"/{LEGAL,LICENSE}
	dodoc "${S1}"/{LEGAL,LICENSE}

	# Update Google search plugin to use UTF8 charset ...
	insinto ${MOZILLA_FIVE_HOME}/searchplugins
	doins "${FILESDIR}"/google.src
}

pkg_preinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	# Remove entire installed instance to solve various problems,
	# for example see bug 27719
	rm -rf "${ROOT}"${MOZILLA_FIVE_HOME}
}

pkg_postinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	# Update the component registry
	MOZILLA_LIBDIR=${ROOT}${MOZILLA_FIVE_HOME} MOZILLA_LAUNCHER=${PN} \
		/usr/libexec/mozilla-launcher -register

	# This should be called in the postinst and postrm of all the
	# mozilla, mozilla-bin, firefox, firefox-bin, thunderbird and
	# thunderbird-bin ebuilds.
	update_mozilla_launcher_symlinks

	ewarn "This is alpha version of Seamonkey-2 and if you are"
	ewarn "have problems with exporting preferences from Seamonkey-1 -"
	ewarn "just copy by hands requred files (prefs.js, ...)"
	ewarn "from ~/.mozilla/default/<profile>/ to ~/.mozilla/seamonkey/<profile>/"
}

pkg_postrm() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	# Update the component registry
	if [[ -x ${MOZILLA_FIVE_HOME}/${PN}-bin ]]; then
		MOZILLA_LIBDIR=${ROOT}${MOZILLA_FIVE_HOME} MOZILLA_LAUNCHER=${PN} \
			/usr/libexec/mozilla-launcher -register
	fi

	update_mozilla_launcher_symlinks
}

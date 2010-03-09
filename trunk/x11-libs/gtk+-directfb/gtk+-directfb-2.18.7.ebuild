EAPI="2"

inherit gnome.org flag-o-matic eutils libtool virtualx

DESCRIPTION="Gimp ToolKit + (directfb target)"
HOMEPAGE="http://www.gtk.org/"

LICENSE="LGPL-2"
SLOT="2"
KEYWORDS=""
IUSE="aqua cups debug jpeg jpeg2k tiff test"
SRC_URI="${SRC_URI//-directfb}"
S="${WORKDIR}/gtk+-${PV}"

RDEPEND=">=x11-libs/cairo-1.6[directfb]
	>=dev-libs/glib-2.21.3
	>=x11-libs/pango-1.20
	>=dev-libs/atk-1.13
	cups? ( net-print/cups )
	jpeg? ( >=media-libs/jpeg-6b-r2:0 )
	jpeg2k? ( media-libs/jasper )
	tiff? ( >=media-libs/tiff-3.5.7 )"
DEPEND="${RDEPEND}
	>=dev-util/pkgconfig-0.9"

pkg_setup() {
	EPREFIX=/usr/$(get_libdir)/dfb
}

src_prepare() {
	# use an arch-specific config directory so that 32bit and 64bit versions
	# dont clash on multilib systems
	local p="${FILESDIR}/${PN//-directfb}"
	has_multilib_profile && epatch "${p}-2.8.0-multilib.patch"

	# Don't break inclusion of gtkclist.h, upstream bug 536767
	epatch "${p}-2.14.3-limit-gtksignal-includes.patch"

	use ppc64 && append-flags -mminimal-toc

	# Non-working test in gentoo's env
	sed 's:\(g_test_add_func ("/ui-tests/keys-events.*\):/*\1*/:g' \
		-i gtk/tests/testing.c || die "sed 1 failed"
	sed '\%/recent-manager/add%,/recent_manager_purge/ d' \
		-i gtk/tests/recentmanager.c || die "sed 2 failed"

	if use x86-interix; then
		# activate the itx-bind package...
		append-flags "-I${EPREFIX}/usr/include/bind"
		append-ldflags "-L${EPREFIX}/usr/lib/bind"
	fi

	elibtoolize
}

src_configure() {
	# need libdir here to avoid a double slash in a path that libtool doesn't
	# grok so well during install (// between $EPREFIX and usr ...)
	econf \
		$(use_with jpeg libjpeg) \
		$(use_with jpeg2k libjasper) \
		$(use_with tiff libtiff) \
		$(use_enable cups cups auto) \
		--sysconfdir="${EPREFIX}/etc" --{datarootdir,datadir}="${EPREFIX}/usr/share" --mandir="${EPREFIX}/usr/share/man" --libdir="${EPREFIX}/usr/$(get_libdir)" --prefix="${EPREFIX}" \
		--with-gdktarget=directfb --without-x
}

src_install() {
	emake install DESTDIR="${D}"
	cd "${D}/${EPREFIX}" && cp "usr/$(get_libdir)/pkgconfig"/*directfb* "${D}" --parents
	cd "${S}"
}

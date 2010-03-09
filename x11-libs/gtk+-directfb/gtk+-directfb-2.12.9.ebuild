EAPI="2"

inherit gnome.org flag-o-matic eutils libtool virtualx

DESCRIPTION="Gimp ToolKit + (directfb target)"
HOMEPAGE="http://www.gtk.org/"

LICENSE="LGPL-2"
SLOT="2"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~sh ~sparc ~x86 ~x86-fbsd ~x86-freebsd ~x86-interix ~amd64-linux ~x86-linux ~ppc-macos ~x86-macos ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="aqua cups debug jpeg jpeg2k tiff test"
SRC_URI="${SRC_URI//-directfb}
	http://wiki.mozilla.org/images/c/c4/001-gtk%2B-2.12.9-dok4.zip
	http://wiki.mozilla.org/images/3/3e/002-gtk%2B-2.12.9-gdkkeys_fix.zip
	http://wiki.mozilla.org/images/2/2b/003-gtk%2B-2.12.9-dok-scroll-experimental.patch.zip
	http://wiki.mozilla.org/images/c/cb/004-gtk%2B-2.12.9-dok-visual-fix.patch.zip
	http://wiki.mozilla.org/images/a/ac/005-gtk%2B-2.12.9-dok-event-block-fix.patch.zip
	http://wiki.mozilla.org/images/c/c0/006-gtk%2B-2.12.9-dok-set-default-display-fix.patch.zip
	http://wiki.mozilla.org/images/4/40/007-gtk%2B-2.12.9-dok-set-focus-fixes.patch.zip"
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
	EPATCH_SUFFIX="patch" EPATCH_FORCE="yes" epatch "${WORKDIR}"
	# use an arch-specific config directory so that 32bit and 64bit versions
	# dont clash on multilib systems
	local p="${FILESDIR}/${PN//-directfb}"
	has_multilib_profile && epatch "${p}-2.8.0-multilib.patch"

	use ppc64 && append-flags -mminimal-toc

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

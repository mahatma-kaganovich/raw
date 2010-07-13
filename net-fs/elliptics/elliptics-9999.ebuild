inherit eutils autotools `[[ "${PVR}" == *9999* ]] && echo git`

EAPI=3

DESCRIPTION="The elliptics network"
HOMEPAGE="http://www.ioremap.net/projects/elliptics"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="ssl fastcgi tokyocabinet"
RDEPEND="ssl? ( dev-libs/openssl )
	fastcgi? ( dev-libs/fcgi )
	tokyocabinet? ( dev-db/tokyocabinet )
	dev-libs/libatomic
	dev-libs/libevent"
DEPEND="${RDEPEND}"

EGIT_REPO_URI="http://www.ioremap.net/git/${PN}.git"

src_prepare(){
	eautoreconf
}

src_configure(){
	local myconf
	mkdir -p ${TMPDIR}/include
	use !tokyocabinet && myconf="${myconf} --with-tokyocabinet-path=${TMPDIR}"
	use !fastcgi && myconf="${myconf} --with-libfcgi-path=${TMPDIR}"
	econf $(use_enable ssl openssl) ${myconf}
}

src_install(){
	emake install{,-info,-man}  DESTDIR="${D}" || die
	use fastcgi && example/fcgi/lighttpd-fastcgi-elliptics.conf
	dodoc doc/design_notes.txt \
		doc/io_storage_backend.txt \
		example/check/README.check \
		example/ioserv.conf
}
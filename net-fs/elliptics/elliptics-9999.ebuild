inherit eutils autotools `[[ "${PVR}" == *9999* ]] && echo git`

EAPI=3

DESCRIPTION="The elliptics network"
HOMEPAGE="http://www.ioremap.net/projects/elliptics"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="fastcgi python"
RDEPEND="dev-libs/openssl
	fastcgi? ( dev-libs/fcgi )
	dev-db/kyotocabinet
	dev-libs/boost[python=]
	dev-libs/libevent"
#	dev-libs/libatomic
DEPEND="${RDEPEND}"

EGIT_REPO_URI="http://www.ioremap.net/git/${PN}.git"

src_prepare(){
	eautoreconf
}

src_configure(){
	econf --with-libatomic-path=/dev/null
}

src_install(){
	emake install DESTDIR="${D}" || die
	use fastcgi && example/fcgi/lighttpd-fastcgi-elliptics.conf
	dodoc doc/design_notes.txt \
		doc/io_storage_backend.txt \
		example/EXAMPLE \
		example/check/README.check \
		example/ioserv.conf
}

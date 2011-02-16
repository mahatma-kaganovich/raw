inherit eutils autotools `[[ "${PVR}" == *9999* ]] && echo git`

EAPI=3

DESCRIPTION="The elliptics network"
HOMEPAGE="http://www.ioremap.net/projects/elliptics"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
# not built without ssl but may be devel
IUSE="+ssl fastcgi"
RDEPEND="ssl? ( dev-libs/openssl )
	fastcgi? ( dev-libs/fcgi )
	dev-db/kyotocabinet
	dev-libs/libatomic
	dev-libs/libevent"
DEPEND="${RDEPEND}"

EGIT_REPO_URI="http://www.ioremap.net/git/${PN}.git"

src_prepare(){
	eautoreconf
}

src_configure(){
	econf $(use_enable ssl openssl)
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
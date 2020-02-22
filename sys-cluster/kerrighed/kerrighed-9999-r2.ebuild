EAPI=4
inherit eutils autotools git-r3

EGIT_REPO_URI="git://kerrighed.git.sourceforge.net/gitroot/kerrighed/tools"

SLOT="0"
DESCRIPTION="Kerrighed is a Single System Image operating system for clusters"
HOMEPAGE="http://www.kerrighed.org/"
RDEPEND="=sys-kernel/kerrighed-sources-${PVR}"
DEPEND="dev-libs/libxslt"
#	sys-apps/lsb-release
KEYWORDS="~amd64 ~x86"

S="${WORKDIR}"

src_prepare(){
	eautoreconf
}

src_configure(){
	econf --disable-kernel || die
}

src_install(){
	emake DESTDIR="${D}" install
	newinitd "${FILESDIR}"/kerrighed.init kerrighed
	newconfd "${S}"/tools/scripts/default/all kerrighed
}

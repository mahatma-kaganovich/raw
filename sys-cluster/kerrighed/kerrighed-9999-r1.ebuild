inherit eutils autotools git

EGIT_REPO_URI="git://mirrors.git.kernel.org/cluster/kerrighed/tools"
EGIT_BRANCH="master"
EGIT_COMMIT="master"

SLOT="0"
DESCRIPTION="Kerrighed is a Single System Image operating system for clusters"
HOMEPAGE="http://www.kerrighed.org/"
RDEPEND="=sys-kernel/kerrighed-sources-${PVR}"
DEPEND="dev-libs/libxslt"
#	sys-apps/lsb-release
KEYWORDS="~amd64 ~x86"

S="${WORKDIR}"

src_unpack(){
	git_src_unpack
	cd "${S}"
	eautoreconf
}

src_compile(){
	econf --disable-service --disable-kernel || die
	emake
}

src_install(){
	emake DESTDIR="${D}" install
	newinitd "${FILESDIR}"/kerrighed.init kerrighed
	newconfd "${S}"/tools/scripts/default/all kerrighed
}

inherit eutils autotools `[[ "${PVR}" == *9999* ]] && echo git`

EAPI=3

MY_PN="atomic"
DESCRIPTION="Atomic access implementation"
HOMEPAGE="http://www.ioremap.net/projects/libatomic"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64" # ~sparc ~ppc

if [[ "${PVR}" == *9999* ]]; then
	EGIT_REPO_URI="http://www.ioremap.net/git/${PN}.git"
else
	SRC_URI="http://www.ioremap.net/archive/libatomic/${MY_PN}-${PV}.tar.gz"
	S="${WORKDIR}/${MY_PN}-${PV}"
fi

src_prepare(){
	eautoreconf
}

src_install(){
	emake install DESTDIR="${D}" || die
}

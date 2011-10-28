EAPI=4
inherit eutils autotools git-2

EGIT_REPO_URI="git://kerrighed.git.sourceforge.net/gitroot/kerrighed/k3m"

SLOT="0"
DESCRIPTION="Kerrighed configuration GUI"
HOMEPAGE="http://www.kerrighed.org/"
DEPEND="dev-games/openscenegraph"
#RDEPEND="$DEPEND sys-cluster/kerrighed"
KEYWORDS="~amd64 ~x86"

S="${WORKDIR}"

src_prepare(){
	eautoreconf
}


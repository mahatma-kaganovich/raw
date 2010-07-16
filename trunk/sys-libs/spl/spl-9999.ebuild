inherit eutils raw-mod `[[ "${PVR}" == *9999* ]] && echo git`
EAPI=3
DESCRIPTION="Solaris Porting Layer Linux kernel module"
HOMEPAGE="http://wiki.github.com/behlendorf/${PN}/"
LICENSE="CDDL"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE=""
DEPEND="${RDEPEND}"
if [[ "${PVR}" == *9999* ]]; then
	EGIT_REPO_URI="git://github.com/behlendorf/${PN}.git"
else
	SRC_URI="http://github.com/behlendorf/${PN}/tarball/${P} -> ${P}.tar.gz"
fi

src_prepare(){
	cd "${WORKDIR}"
	mv *-${PN}-* "${S}"
	cd "${S}" || die
	sed -i -e 's:\(if test -r $kernelbuild/include/linux/version.h &&\):kernsrcver=`cat $kernelbuild/include/config/kernel.release 2>/dev/null` || \1:g' config/kernel.m4 configure
}

EAPI=3

# possible deprecated package
inherit eutils autotools `[[ "${PVR}" == *9999* ]] && echo "git"`

DESCRIPTION="POHMELFS userspace server"
HOMEPAGE="http://www.ioremap.net/projects/pohmelfs"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="+kernel"
RDEPEND=""
DEPEND="${RDEPEND}"

EGIT_REPO_URI="http://www.ioremap.net/git/${PN}.git"
SRC_URI="http://www.ioremap.net/cgi-bin/gitweb.cgi?p=pohmelfs-server.git;a=snapshot;h=13b9a671e7634919675cc168e071a2e70b8e31e8 -> ${PN}-${PVR}.tar.bz2
	http://www.ioremap.net/cgi-bin/gitweb.cgi?p=pohmelfs.git;a=snapshot;h=dda7d4d584a48fb2d9a428d9f94b8e4039e42061 -> pohmelfs-${PVR}.tar.bz2"

S="${WORKDIR}/pohmelfs-server.git"
KERNEL_DIR=/usr/src/linux

src_prepare(){
	if use kernel; then
		mkdir -p "${WORKDIR}"/include/linux
		echo "typedef void backing_dev_info;" >"${WORKDIR}"/include/linux/backing-dev.h
		ln -s "${WORKDIR}"/include/linux include/linux
	fi
	eautoreconf
}

src_configure(){
	local i="${WORKDIR}"/pohmelfs.git
	use kernel && for i in "${KERNEL_DIR}/drivers/staging/pohmelfs" "${KERNEL_DIR}"; do
		[[ -e "${i}" ]] && break
	done
	econf --with-kdir-path="${i}"
}

src_install(){
	emake install DESTDIR="${D}" || die
}

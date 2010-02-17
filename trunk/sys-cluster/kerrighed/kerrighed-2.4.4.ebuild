inherit eutils linux-mod

SLOT="0"
DESCRIPTION="Kerrighed is a Single System Image operating system for clusters"
HOMEPAGE="http://www.kerrighed.org/"
SRC_URI="http://gforge.inria.fr/frs/download.php/26017/${P}.tar.gz"
DEPEND="=sys-kernel/kerrighed-sources-${PV}"
#	sys-apps/lsb-release"
KEYWORDS="~amd64 ~x86"

KV="2.6.20-krg"
KERNEL_DIR="/usr/src/linux-${KV}"

src_compile(){
	ln -s "${KERNEL_DIR}" ${S}/kernel
	econf --disable-service --disable-kernel || die
	emake || die
}

src_install(){
	emake DESTDIR="${D}" install || die
	newinitd "${FILESDIR}"/kerrighed.init kerrighed
	newconfd "${S}"/tools/scripts/default/all kerrighed
}

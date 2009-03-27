inherit eutils raw-mod

SLOT="0"
DESCRIPTION="Kerrighed is a Single System Image operating system for clusters"
HOMEPAGE="http://www.kerrighed.org/"
SRC_URI="http://gforge.inria.fr/frs/download.php/4491/${P}.tar.gz"
DEPEND="=sys-kernel/kerrighed-sources-${PV}
	app-text/xmlto"
#	sys-apps/lsb-release"
KEYWORDS="~amd64 ~x86"

KV="2.6.20-krg"
KERNEL_DIR="/usr/src/linux-${KV}"

src_unpack(){
	unpack "${P}.tar.gz"
	sed -i -e 's%http://www.oasis-open.org/docbook/xml/4.1.2/docbookx.dtd%none%g' "${S}"/tools/man/*.xml
	sed -i -e 's%$(DOCBOOK2MAN)%$(DOCBOOK2MAN) --skip-validation%' "${S}"/tools/man/Makefile.in
}

src_compile(){
	kern_prepare
	econf --with-kernel="${KERNEL_DIR}" --disable-service || die
	mmake
}

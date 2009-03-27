K_SECURITY_UNSUPPORTED="1"
ETYPE="sources"
CKV="2.6.20"

inherit kernel-2

EXTRAVERSION="krg"
OKV="${CKV}"
KV="${OKV}-${EXTRAVERSION}"
KV_FULL="${KV}"
K_NOSETEXTRAVERSION="1"

HOMEPAGE="http://www.kerrighed.org/"
DESCRIPTION="Kerrighed SSI cluster kernel"
SRC_URI="${KERNEL_URI} http://gforge.inria.fr/frs/download.php/4491/kerrighed-${PV}.tar.gz"
KEYWORDS="-* ~amd64 ~x86"
IUSE=""

S="${WORKDIR}/linux-${KV}"
S1="${WORKDIR}/kerrighed-${PV}"

src_unpack(){
	unpack "kerrighed-${PV}.tar.gz"
	kernel-2_src_unpack
	sed -i -e 's/#include <string.h>/\n#include <string.h>\n#include <limits.h>/' "${S}/scripts/mod/sumversion.c"
	cd "${S1}"
	econf --with-kernel="${S}" --disable-service
	emake patch
}

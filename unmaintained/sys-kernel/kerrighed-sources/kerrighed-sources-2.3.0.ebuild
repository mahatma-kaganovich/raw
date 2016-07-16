EAPI=2
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

# for build-kernel feature only
# default: building default kernel, including all modules compressed in initrd
IUSE="+build-kernel +pnp"

KERNEL_CONFIG="${KERNEL_CONFIG} -IPC_NS -PREEMPT[\w\d_]* PREEMPT_NONE -KEYS
	-IPV6 -NET_IPIP -NET_IPGRE -DUMMY -BONDING -EQUALIZER"

S="${WORKDIR}/linux-${KV}"
S1="${WORKDIR}/kerrighed-${PV}"

src_unpack(){
	unpack "kerrighed-${PV}.tar.gz"
	kernel-2_src_unpack
	cd "${S}"
	# glibc 2.8+
	grep -q "<limits.h>" scripts/mod/sumversion.c || sed -i -e 's/#include <string.h>/\n#include <string.h>\n#include <limits.h>/' scripts/mod/sumversion.c
	# gcc 4.2+
	sed -i -e 's/_proxy_pda = 0/_proxy_pda = 1/g' arch/*/kernel/vmlinux.lds.S
	[[ -e arch/x86_64/kernel/x8664_ksyms.c ]] && ( grep -q "_proxy_pda" arch/x86_64/kernel/x8664_ksyms.c || echo "EXPORT_SYMBOL(_proxy_pda);" >>arch/x86_64/kernel/x8664_ksyms.c )
	cd "${S1}"
	econf --with-kernel="${S}" --disable-service --disable-man
	emake patch
}

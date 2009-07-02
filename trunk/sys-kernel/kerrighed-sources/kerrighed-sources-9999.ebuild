K_SECURITY_UNSUPPORTED="1"
ETYPE="sources"

inherit autotools kernel-2 subversion

ESVN_REPO_URI="svn://scm.gforge.inria.fr/svn/kerrighed/trunk"

KV=""
K_NOSETEXTRAVERSION="1"

#set_kv 2.6.20-krg

HOMEPAGE="http://www.kerrighed.org/"
DESCRIPTION="Kerrighed SSI cluster kernel and tools"
KEYWORDS="-* ~amd64 ~x86"
DEPEND="dev-libs/libxslt
	!sys-cluster/kerrighed"

IUSE="+build-kernel +pnp"

KERNEL_CONFIG="${KERNEL_CONFIG} -IPC_NS -PREEMPT[\w\d_]* PREEMPT_NONE -KEYS
	-IPV6 -NET_IPIP -NET_IPGRE -DUMMY -BONDING -EQUALIZER"

S="${WORKDIR}/kernel"
S1="${WORKDIR}"

src_unpack(){
	S="${S1}" subversion_src_unpack
	check_kv
	cd "${S}"
	# glibc 2.8+
	grep -q "<limits.h>" scripts/mod/sumversion.c || sed -i -e 's/#include <string.h>/\n#include <string.h>\n#include <limits.h>/' scripts/mod/sumversion.c
	# gcc 4.2+
	sed -i -e 's/_proxy_pda = 0/_proxy_pda = 1/g' arch/*/kernel/vmlinux.lds.S
	[[ -e arch/x86_64/kernel/x8664_ksyms.c ]] && ( grep -q "_proxy_pda" arch/x86_64/kernel/x8664_ksyms.c || echo "EXPORT_SYMBOL(_proxy_pda);" >>arch/x86_64/kernel/x8664_ksyms.c )
	cd "${S1}"
	eautoreconf
	econf --disable-service || die
}

src_compile(){
	use build-kernel || die '"build-kernel" useflag required!'
	kernel-2_src_compile
	cd "${S1}"
	kmake || die
}

src_install(){
	kernel-2_src_install
	cd "${S1}"
	kmake DESTDIR="${D}" install
	rm "${D}"/boot/*.old
	mv "${S}" "${D}"/usr/src/linux-${KV}
}

EAPI=2
K_SECURITY_UNSUPPORTED="1"
ETYPE="sources"

inherit autotools kernel-2 subversion

ESVN_REPO_URI="svn://scm.gforge.inria.fr/svn/kerrighed/trunk"

KV=""
K_NOSETEXTRAVERSION="1"
KV_PATCH=0

#set_kv 2.6.20-krg

HOMEPAGE="http://www.kerrighed.org/"
DESCRIPTION="Kerrighed SSI cluster kernel and tools"
KEYWORDS="-* ~amd64 ~x86"
DEPEND="dev-libs/libxslt
	!sys-cluster/kerrighed"

IUSE="+build-kernel +pnp"

KERNEL_CONFIG="${KERNEL_CONFIG}
	===kerrighed:
	-IPC_NS -PREEMPT -PREEMPT_VOLUNTARY PREEMPT_NONE -KEYS -NUMA
	===
	"

S="${WORKDIR}/kernel"
S1="${WORKDIR}"

src_unpack(){
	S="${S1}" subversion_src_unpack
	check_kv
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
#	newinitd "${FILESDIR}"/kerrighed.init kerrighed
#	newconfd "${S1}"/scripts/default/all kerrighed
}

EAPI=2
K_SECURITY_UNSUPPORTED="1"
ETYPE="sources"
CKV="2.6.30"

inherit kernel-2

EXTRAVERSION="krg"
OKV="${CKV}"
KV="${OKV}-${EXTRAVERSION}"
KV_FULL="${KV}"
K_NOSETEXTRAVERSION="1"

HOMEPAGE="http://www.kerrighed.org/"
DESCRIPTION="Kerrighed SSI cluster kernel"
SRC_URI="${KERNEL_URI} http://gforge.inria.fr/frs/download.php/27161/kerrighed-${PV}.tar.gz"
KEYWORDS="-* ~amd64"

# for build-kernel feature only
# default: building default kernel, including all modules compressed in initrd
IUSE="+build-kernel +pnp -multilib"

KERNEL_CONFIG="${KERNEL_CONFIG} PREEMPT_NONE -KEYS -NUMA -IA32_EMULATION"

S1="${WORKDIR}/kerrighed-${PV}"
S="${S1}/_kernel"

src_unpack(){
	unpack "kerrighed-${PV}.tar.gz"
#	kernel-2_src_unpack
	ln -s "${DISTDIR}/linux-${CKV}.tar.bz2" "${S1}"/patches
	filter-flags -ftracer
	cd "${S1}"
	econf || die
}

src_install(){
	kernel-2_src_install
	mv "${S}" "${D}"/usr/src/linux-${KV}
}

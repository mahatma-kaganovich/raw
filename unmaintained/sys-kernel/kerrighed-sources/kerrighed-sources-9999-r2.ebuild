EAPI=4
K_SECURITY_UNSUPPORTED="1"
ETYPE="sources"

inherit kernel-2 git-r3

EGIT_REPO_URI="git://kerrighed.git.sourceforge.net/gitroot/kerrighed/kernel"

KV="" # autodetect by overlayed kernel-2.eclass
K_NOSETEXTRAVERSION="1"
KV_PATCH=0

HOMEPAGE="http://www.kerrighed.org/"
DESCRIPTION="Kerrighed SSI cluster kernel"
KEYWORDS="-* ~amd64 ~x86"
#PDEPEND="=sys-cluster/kerrighed-${PVR}"
IUSE="+build-kernel +pnp -multilib"

KERNEL_CONFIG="${KERNEL_CONFIG}
	===kerrighed: PREEMPT_NONE -KEYS -NUMA -IA32_EMULATION
	"

src_prepare(){
	kernel-2_src_prepare
	sed -i -e 's%-Werror% %' "${S}"/kerrighed/scheduler/Makefile
	sed -i -e 's%^\(EXTRAVERSION =\)$%\1 -krg%' "${S}"/Makefile
	filter-flags -ftracer
}

src_install(){
	kernel-2_src_install
	mv "${S}" "${D}"/usr/src/linux-${KV}
}

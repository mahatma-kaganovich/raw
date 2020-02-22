EAPI=2
K_SECURITY_UNSUPPORTED="1"
ETYPE="sources"

inherit kernel-2 git-r3

EGIT_REPO_URI="git://mirrors.git.kernel.org/cluster/kerrighed/kernel"
EGIT_BRANCH="master"
EGIT_COMMIT="master"

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

S="${WORKDIR}/kernel"

src_unpack(){
	mkdir "${S}"
	cd "${S}" || die
	git-r3_src_unpack
	sed -i -e 's%-Werror% %' "${S}"/kerrighed/scheduler/Makefile
	sed -i -e 's%^\(EXTRAVERSION =\)$%\1 -krg%' "${S}"/Makefile
	filter-flags -ftracer
}

src_install(){
	kernel-2_src_install
	mv "${S}" "${D}"/usr/src/linux-${KV}
}

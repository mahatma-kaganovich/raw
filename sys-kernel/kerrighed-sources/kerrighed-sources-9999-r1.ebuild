K_SECURITY_UNSUPPORTED="1"
ETYPE="sources"

inherit kernel-2 git

EGIT_REPO_URI="git://mirrors.git.kernel.org/cluster/kerrighed/kernel"
EGIT_BRANCH="master"
EGIT_TREE="master"

KV="" # autodetect by overlayed kernel-2.eclass
K_NOSETEXTRAVERSION="1"

HOMEPAGE="http://www.kerrighed.org/"
DESCRIPTION="Kerrighed SSI cluster kernel"
KEYWORDS="-* ~amd64 ~x86"
#PDEPEND="=sys-cluster/kerrighed-${PVR}"
IUSE="+build-kernel +pnp"

KERNEL_CONFIG="${KERNEL_CONFIG}
	===kerrighed:
	-PREEMPT -PREEMPT_VOLUNTARY PREEMPT_NONE -KEYS -IA32_EMULATION
	-NTFS_FS -BLK_DEV_UMEM -NUMA
	===
	"
#	-NET_IPIP -NET_IPGRE -DUMMY -BONDING -EQUALIZER

S="${WORKDIR}/kernel"

src_unpack(){
	mkdir "${S}"
	cd "${S}" || die
	git_src_unpack
	sed -i -e 's%-Werror% %' "${S}"/kerrighed/scheduler/Makefile
	sed -i -e 's%^\(EXTRAVERSION =\)$%\1 -krg%' "${S}"/Makefile
}

src_install(){
	kernel-2_src_install
	mv "${S}" "${D}"/usr/src/linux-${KV}
}

EAPI=3
inherit eutils linux-mod versionator

DESCRIPTION="RedHat cluster packages (gfs2, dlm, etc)"
HOMEPAGE="http://sources.redhat.com/cluster/wiki/"
SRC_URI="ftp://sources.redhat.com/pub/cluster/releases/${P}.tar.gz"

#LICENSE="|| ( GPL-2.1 GPL-3 )"
LICENSE=">=GPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="xen"

DEPEND=">=sys-kernel/linux-headers-2.6.24
	!sys-cluster/dlm-headers
	!sys-cluster/dlm-kernel
	!sys-cluster/dlm
	!sys-cluster/dlm-lib
	!sys-cluster/cman-lib
	sys-cluster/corosync
	dev-python/pexpect
	net-nds/openldap
	xen? ( app-emulation/libvirt )
	"

RDEPEND="${DEPEND}"

src_prepare(){
	# fix the manual pages have executable bit
	use xen || rm fence/agents/xvm -Rf
	sed -i -e '
		/\tinstall -d/s/install/& -m 0755/; t
		/\tinstall/s/install/& -m 0644/' \
		dlm/man/Makefile || die "failed patching man pages permission"
	sed -i -e 's:_PLATFORM_H:_PLATFORM__RGM_H:' rgmanager/include/platform.h
}

src_configure() {
	export LANG="C"
	export LC_ALL="C"
	./configure \
		--prefix=/usr \
		--cc="$(tc-getCC)" \
		--ldflags="${LDFLAGS}" \
		--cflags="${CFLAGS}" \
		--libdir="/usr/$(get_libdir)" \
		--disable_kernel_check \
		--kernel_src="${KERNEL_DIR}" \
		--nssincdir="/usr/include/nss" \
		--nsprincdir="/usr/include/nspr" \
			|| die
}

src_compile(){
	emake || die
}

src_install() {
	emake DESTDIR="${D}" install || die
}

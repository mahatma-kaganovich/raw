inherit eutils linux-mod versionator

EAPI=3

DESCRIPTION="RedHat cluster packages (gfs2, dlm, etc)"
HOMEPAGE="http://sources.redhat.com/cluster/wiki/"
SRC_URI="https://fedorahosted.org/releases/c/l/${PN}/${P}.tar.xz"
RESTRICT=nomirror

#LICENSE="|| ( GPL-2.1 GPL-3 )"
LICENSE=">=GPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="xen dbus"

DEPEND=">=sys-kernel/linux-headers-2.6.24
	!sys-cluster/dlm-headers
	!sys-cluster/dlm-kernel
	!sys-cluster/dlm
	!sys-cluster/dlm-lib
	!sys-cluster/cman-lib
	sys-cluster/corosync
	sys-cluster/openais
	sys-libs/slang
	xen? ( app-emulation/libvirt )
	dbus? ( sys-apps/dbus )"

RDEPEND="${DEPEND}"

src_prepare(){
	# fix the manual pages have executable bit
	sed -i -e '
		/\tinstall -d/s/install/& -m 0755/; t
		/\tinstall/s/install/& -m 0644/' \
		dlm/man/Makefile || die "failed patching man pages permission"
}

src_configure() {
	./configure \
                --prefix=/usr \
		--cc="$(tc-getCC)" \
		--ldflags="${LDFLAGS}" \
		--cflags="${CFLAGS}" \
		--libdir="/usr/$(get_libdir)" \
		--disable_kernel_check \
		$(use dbus||echo --disable_dbus) \
		--without_rgmanager \
		--enable_contrib \
		--kernel_src="${KERNEL_DIR}" \
			|| die
}

src_compile(){
	emake || die
}

src_install() {
	emake DESTDIR="${D}" install || die
	mv "${D}"/etc/init.d/cman "${D}"/usr/share/doc/cluster/cman.init
}

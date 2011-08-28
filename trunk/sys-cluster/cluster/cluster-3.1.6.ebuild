inherit eutils

EAPI=3

DESCRIPTION="RedHat cluster packages"
HOMEPAGE="http://sources.redhat.com/cluster/wiki/"
SRC_URI="https://fedorahosted.org/releases/c/l/${PN}/${P}.tar.xz"

#LICENSE="|| ( GPL-2.1 GPL-3 )"
LICENSE=">=GPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="xen dbus ldap"

DEPEND=">=sys-kernel/linux-headers-2.6.24
	!sys-cluster/dlm-headers
	!sys-cluster/dlm
	!sys-cluster/dlm-lib
	!sys-cluster/cman-lib
	!sys-cluster/ccs
	!sys-cluster/rgmanager
	sys-cluster/corosync
	>=sys-cluster/openais-1.1.4
	sys-libs/slang
	ldap? ( net-nds/openldap )
	xen? ( app-emulation/libvirt )
	dbus? ( sys-apps/dbus )"
# 	>=sys-cluster/corosync-1.4.1

RDEPEND="${DEPEND}"

src_prepare(){
	ewarn "According to wiki, this version requred >=sys-cluster/corosync-1.4.1"
	ewarn "But it is compiling with 1.3.3 (Gentoo current mainline) and I keep unchecked"
	ewarn "If unsure - say 'emerge =sys-cluster/cluster-3.0.12.1' instead"
	# vs. dev-libs/libxml2[icu] -> icu -> unicode/platform.h interfere with
	sed -i -e 's:_PLATFORM_H:_PLATFORM__RGM_H:' rgmanager/include/platform.h
	use ldap || sed -i -e 's:ldap::g' config/*/Makefile
	sed -i -e 's:LD_FLAGS:LDFLAGS:' rgmanager/src/daemons/Makefile
}

src_configure() {
	./configure \
		--prefix=/usr \
		--cc="$(tc-getCC)" \
		${LDFLAGS:+--ldflags="${LDFLAGS}"} \
		${CFLAGS:+--cflags="${CFLAGS}"} \
		${CPPFLAGS:+--extracflags="${CPPFLAGS}"} \
		--libdir="/usr/$(get_libdir)" \
		--disable_kernel_check \
		--kernel_src=""${ROOT}/usr"" \
		$(use dbus||echo --disable_dbus) \
		--enable_contrib \
			|| die
}

src_install() {
	emake DESTDIR="${D}" install || die
	local l='' n d='/usr/share/cluster/init.d'
	dodir $d
	for n in cman rgmanager; do
		# lazy wrapper to RH's
		mv "${D}/etc/init.d/$n" "${D}$d"
		echo "#!/sbin/runscript

depens(){
	use net
	${l:+need$l}
}
opts=\"${opts} reload status\"
_do(){
	ebegin \"\${1}ing $n\"
	$d/$n \$1
	eend \$?
}
start(){ _do start;}
stop(){ _do stop;}
restart(){ _do restart;}
reload(){ _do reload;}
status(){ $d/$n status;}" >"$TMPDIR/$n"
		doinitd "$TMPDIR/$n"
#		l+=" $n"
		l=" $n"
	done
}

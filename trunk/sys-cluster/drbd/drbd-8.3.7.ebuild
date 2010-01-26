EAPI="2"

# drbd-8.3.9999.ebuild
GIT=$([[ ${PVR} = *.9999 ]] && echo "git autotools")
EGIT_REPO_URI="git://git.drbd.org/drbd-${PV%.9999}.git"
inherit eutils versionator ${GIT}

LICENSE="GPL-2"
KEYWORDS="~amd64 ~x86"

MY_P="${PN}-${PV/_rc/rc}"

MY_MAJ_PV="$(get_version_component_range 1-2 ${PV})"
DESCRIPTION="mirror/replicate block-devices across a network-connection"
SRC_URI="http://oss.linbit.com/drbd/${MY_MAJ_PV}/"${MY_P}".tar.gz"
HOMEPAGE="http://www.drbd.org"

IUSE=""

DEPEND=""
RDEPEND=""
PDEPEND=""

SLOT="0"

S="${WORKDIR}/${MY_P}"

if [[ -n "${GIT}" ]] ; then
	SRC_URI=""
	IUSE="${IUSE} +doc"
	DEPEND="${DEPEND} doc? ( dev-libs/libxslt app-text/docbook-xsl-stylesheets ) "
	src_unpack(){
		git_src_unpack
		cd "${S}"
		eautoreconf
		use doc || sed -i -e 's/ documentation / /g' Makefile.in
	}
fi

src_configure() {
	econf \
		--localstatedir=/var \
		--with-utils \
		--without-km \
		--without-udev \
		--with-xen \
		--without-pacemaker \
		--with-heartbeat \
		--without-rgmanager \
		--without-bashcompletion \
		--with-distro=gentoo \
		|| die "configure failed"
}

src_compile() {
	emake XSLTPROC_OPTIONS="--xinclude --novalid" tools $(use doc && echo "doc") || die "compile problem"
}

src_install() {
	emake DESTDIR="${D}" KDIR="${KERNEL_DIR}" install-tools || die "install problem"

	# gentoo-ish init-script
	newinitd "${FILESDIR}"/${PN}-8.0.rc ${PN} || die

	# manually install udev rules
	insinto /etc/udev/rules.d
	newins scripts/drbd.rules 65-drbd.rules || die

	# manually install bash-completion script
	insinto /usr/share/bash-completion
	newins scripts/drbdadm.bash_completion drbdadm

	# docs
	dodoc README ChangeLog

	# we put drbd.conf into docs
	# it doesnt make sense to install a default conf in /etc
	# put it to the docs
	rm -f "${D}"/etc/drbd.conf
	dodoc scripts/drbd.conf || die
}

pkg_postinst() {
	einfo ""
	einfo "Please copy and gunzip the configuration file"
	einfo "from /usr/share/doc/${PF}/drbd.conf.gz to /etc"
	einfo "and edit it to your needs. Helpful commands:"
	einfo "man 5 drbd.conf"
	einfo "man 8 drbdsetup"
	einfo "man 8 drbdadm"
	einfo "man 8 drbddisk"
	einfo "man 8 drbdmeta"
	einfo ""
}

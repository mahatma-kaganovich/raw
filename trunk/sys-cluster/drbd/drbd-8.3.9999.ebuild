
# drbd-8.3.9999.ebuild
GIT=$([[ ${PVR} = *.9999 ]] && echo "git")
EGIT_REPO_URI="git://git.drbd.org/drbd-${PV%.9999}.git"

KERNEL_DIR=""
# with empty KERNEL_DIR - using linux-headers instead of kernel
inherit eutils versionator ${GIT} # linux-info

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
PDEPEND="~sys-cluster/drbd-kernel-${PV}"

SLOT="0"

S="${WORKDIR}/${MY_P}"

if [[ "${GIT}" == "git" ]] ; then
	SRC_URI=""
	IUSE="${IUSE} +doc"
#	DEPEND="${DEPEND} doc? ( app-text/docbook-sgml-utils ) "
	DEPEND="${DEPEND} doc? ( app-text/xmlto ) "
fi

src_unpack(){
	if [[ "${GIT}" == "git" ]] ; then
		git_src_unpack
		if use doc ; then
			cd "${S}"/documentation || die
			local i
			for i in *.sgml ; do
				sed -i -e 's%\[]>%\n"none">%g' -e 's%<refname>\(.*/\)\(.*\)</refname>%<refname>\2</refname>%g' ${i}
				/usr/bin/perl "${FILESDIR}"/man-fix.pl <${i} >${i}.1
				mv ${i}.1 ${i}
				xmlto man ${i} --skip-validation
			done
		else
			sed -i -e 's/ documentation / /g' Makefile
		fi
	else
		unpack "${A}"
	fi
}

src_compile() {
	emake -j1 OPTFLAGS="${CFLAGS}" KDIR="${KERNEL_DIR}" tools || die "compile problem"
}

src_install() {
	emake -j1 PREFIX="${D}" KDIR="${KERNEL_DIR}" install-tools || die "install problem"

	# gentoo-ish init-script
	newinitd "${FILESDIR}"/${PN}-8.0.rc ${PN} || die

	# docs
	dodoc README ChangeLog ROADMAP

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

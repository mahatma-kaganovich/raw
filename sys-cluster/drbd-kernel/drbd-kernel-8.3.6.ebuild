
# drbd-kernel-8.3.9999.ebuild
GIT=$([[ ${PVR} = *.9999 ]] && echo "git")
EGIT_REPO_URI="git://git.drbd.org/drbd-${PV%.9999}.git"

inherit eutils versionator linux-mod ${GIT}

LICENSE="GPL-2"
KEYWORDS="~amd64 ~x86"

MY_PN="${PN/-kernel/}"
MY_P="${MY_PN}-${PV/_rc/rc}"
MY_MAJ_PV="$(get_version_component_range 1-2 ${PV})"

HOMEPAGE="http://www.drbd.org"
DESCRIPTION="mirror/replicate block-devices across a network-connection"
SRC_URI="http://oss.linbit.com/drbd/${MY_MAJ_PV}/${MY_P}.tar.gz"

IUSE=""

DEPEND="virtual/linux-sources"
RDEPEND=""
SLOT="0"

S="${WORKDIR}/${MY_P}"

[[ "${GIT}" == "git" ]] && SRC_URI=""

pkg_setup() {
	if ! kernel_is 2 6; then
		die "Unsupported kernel, drbd-${PV} needs kernel 2.6.x ."
	fi

	MODULE_NAMES="drbd(block:${S}/drbd)"
	BUILD_TARGETS="default"
	CONFIG_CHECK="CONNECTOR"
	CONNECTOR_ERROR="You must enable \"CONNECTOR - unified userspace <-> kernelspace linker\" in your kernel configuration, because drbd needs it."
	linux-mod_pkg_setup
	BUILD_PARAMS="-j1 KDIR=${KERNEL_DIR} O=${KERNEL_DIR}"
}

pkg_postinst() {
	linux-mod_pkg_postinst

	einfo ""
	einfo "Please remember to re-emerge drbd when you upgrade your kernel!"
	einfo ""
}

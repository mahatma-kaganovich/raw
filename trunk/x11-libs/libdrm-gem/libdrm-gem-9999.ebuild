#SNAPSHOT="yes"
inherit autotools x-modular

EGIT_BRANCH="modesetting-gem"
EGIT_TREE="modesetting-gem"
EGIT_REPO_URI="git://anongit.freedesktop.org/git/mesa/drm"

DESCRIPTION="X.Org libdrm library"
HOMEPAGE="http://dri.freedesktop.org/"
SRC_URI=""

KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~x86-fbsd"

IUSE=""
RDEPEND="dev-libs/libpthread-stubs"
DEPEND="${RDEPEND}"
RESTRICT="test" # see bug #236845

PROVIDE="x11-libs/libdrm"

CONFIGURE_OPTIONS="--enable-udev --enable-nouveau-experimental-api"

pkg_postinst() {
	x-modular_pkg_postinst

	ewarn "libdrm's ABI may have changed without change in library name"
	ewarn "Please rebuild media-libs/mesa, x11-base/xorg-server and"
	ewarn "your video drivers in x11-drivers/*."
}

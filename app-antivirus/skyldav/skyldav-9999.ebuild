# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

if [[ "$PV" == 9999* ]]; then
	git=git-r3
	EGIT_REPO_URI="https://github.com/mahatma-kaganovich/$PN.git"
else
	git=
	SRC_URI="https://github.com/mahatma-kaganovich/$PN/archive/$PN-$PV.tar.gz"
	S="$WORKDIR/$PN-$PV"
fi

#inherit autotools linux-info linux-mod readme.gentoo-r1 systemd $git
inherit autotools linux-info readme.gentoo-r1 systemd $git

DESCRIPTION="Skyld AV: on-access scanning daemon for ClamAV using fanotify"
HOMEPAGE="http://xypron.github.io/skyldav/"

KEYWORDS="amd64 x86"
SLOT="0"
LICENSE="Apache-2.0"
IUSE="libnotify systemd"

RDEPEND=">=app-antivirus/clamav-0.97.8
	sys-apps/util-linux
	sys-libs/libcap
	libnotify? (
		media-libs/libcanberra[gtk2]
		x11-libs/libnotify
		x11-libs/gtk+:2
	)"
DEPEND="${RDEPEND}
	|| ( dev-build/autoconf-archive sys-devel/autoconf-archive )"

## autotools-utils.eclass settings
DOCS=( AUTHORS NEWS README )
PATCHES=(
	"${FILESDIR}/${PN}-examples.patch"
	"${FILESDIR}/${PN}-conf.patch"
)

pkg_setup() {
	linux-info_pkg_setup
	kernel_is ge 3 8 0 || die "Linux 3.8.0 or newer recommended"
	CONFIG_CHECK="FANOTIFY FANOTIFY_ACCESS_PERMISSIONS"
	check_extra_config

	## define contents for README.gentoo
	if use systemd; then
		DOC_CONTENTS='Skyld AV provides a systemd service.'$'\n'
		DOC_CONTENTS+='Please edit the systemd service config file to match your needs:'$'\n'
		DOC_CONTENTS+='/etc/systemd/system/skyldav.service.d/00gentoo.conf'$'\n'
		DOC_CONTENTS+='# systemctl daemon-reload'$'\n'
		DOC_CONTENTS+='# systemctl restart skyldav.service'$'\n'
		DOC_CONTENTS+='Example for enabling the Skyld AV service:'$'\n'
		DOC_CONTENTS+='# systemctl enable skyldav.service'$'\n'
	else
		DOC_CONTENTS='Skyld AV provides an init script for OpenRC.'$'\n'
		DOC_CONTENTS+='Please edit the init script config file to match your needs:'$'\n'
		DOC_CONTENTS+='/etc/conf.d/skyldav'$'\n'
		DOC_CONTENTS+='Example for enabling the Skyld AV init script:'$'\n'
		DOC_CONTENTS+='# rc-update add skyldav default'$'\n'
	fi
}

src_prepare(){
	default
	eautoreconf
}

src_configure() {
	local myeconfargs=(
		$(use_with libnotify notification)
	)
	econf ${myeconfargs[@]}
}

src_install() {
	default
	einstalldocs

	## install systemd service or OpenRC init scripts
	if use systemd; then
		systemd_newunit "${FILESDIR}/skyldav.service-r1" skyldav.service
		systemd_install_serviced "${FILESDIR}"/skyldav.service.conf
		systemd_newtmpfilesd "${FILESDIR}"/skyldav.tmpfilesd skyldav.conf
	else
		newinitd "${FILESDIR}/${PN}.initd" ${PN}
		newconfd "${FILESDIR}/${PN}.confd" ${PN}
	fi

	## create README.gentoo from ${DOC_CONTENTS}
	DISABLE_AUTOFORMATTING=1 readme.gentoo_create_doc
}

pkg_postinst() {
	## workaround for /usr/lib/tmpfiles.d/skyldav.conf
	## not getting processed until the next reboot
	if use systemd; then
		install -d -m 0755 -o root -g root /run/skyldav
	fi
}

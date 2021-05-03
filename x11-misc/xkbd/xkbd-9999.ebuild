# Copyright 1999-2018 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6

if [[ "$PV" == 9999* ]]; then
	git=git-r3
	EGIT_REPO_URI="https://github.com/mahatma-kaganovich/$PN.git"
else
	git=
	SRC_URI="https://github.com/mahatma-kaganovich/$PN/archive/$PN-$PV.tar.gz"
	S="$WORKDIR/$PN-$PN-$PV"
fi
KEYWORDS="amd64 ~arm ~ppc x86"

inherit autotools $git

DESCRIPTION="onscreen soft keyboard for X11"
HOMEPAGE="https://github.com/mahatma-kaganovich/xkbd"

LICENSE="GPL-2"
SLOT="0"
IUSE="debug xpm minimal +multitouch +lock +evdev"

RDEPEND="x11-libs/libX11
	x11-libs/libXft
	x11-libs/libXtst
	x11-libs/libXScrnSaver
	x11-libs/libXext
	evdev? ( dev-libs/libevdev )
	xpm? ( x11-libs/libXpm )
	multitouch? ( x11-libs/libXi )"

DEPEND="${RDEPEND}
	x11-base/xorg-proto:="

RDEPEND="${RDEPEND}
	sys-process/procps
	lock? ( x11-apps/xinput x11-misc/slock sys-process/procps )
	x11-apps/setxkbmap
	x11-apps/xmodmap"

DOCS=( AUTHORS )

src_prepare(){
	default
	eautoreconf
}

src_configure() {
	econf \
		$(use_enable minimal) \
		$(use_enable xpm) \
		$(use_enable multitouch xi) \
		$(use_enable evdev) \
		$(use_enable debug)
}

src_install(){
	default
	local i s="/usr/share/$PN"
	# forget issue about xpm, as not use xpm
#	sed -i -e 's:#000000:#3f7f7f:' -e 's:#424242:#1f3f3f:' -e 's:#444444:#3d7d7d:' -e 's:#aaaaaa:#1f3f3f:' -e 's:#888888:#0f1f1f:' "$D/$s"/img/*.xpm
	use xpm || rm "$D/$s/img" -Rf
	dodir "$s/examples"
	dosym "../usr/share/$PN/xkbd-std-small.conf" /etc/xkbd-config.conf
	mv "$D/$s"/*.xkbd "$D/$s/examples"
}

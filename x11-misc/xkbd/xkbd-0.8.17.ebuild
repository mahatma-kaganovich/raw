# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

DESCRIPTION="onscreen soft keyboard for X11"
HOMEPAGE="https://github.com/mahatma-kaganovich/xkbd"
SRC_URI="https://github.com/mahatma-kaganovich/xkbd/archive/xkbd-0.8.17.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 ~arm ~ppc x86"
IUSE="debug xpm"

RDEPEND="x11-libs/libXrender
	x11-libs/libX11
	x11-libs/libXft
	x11-libs/libXtst
	xpm? ( x11-libs/libXpm )
	media-libs/freetype
	dev-libs/expat
	sys-libs/zlib"
DEPEND="${RDEPEND}
	x11-proto/xproto
	x11-proto/xextproto"

RDEPEND="${RDEPEND}
	x11-apps/xmodmap"

DOCS=( AUTHORS )
S="$WORKDIR/$PN-$PN-$PV"

src_prepare(){
	default
	# postfixed
	sed -i -e "s:/ya/:/:" "$S"/data/xkbd-onoff
}

src_configure() {
	econf \
		$(use_enable xpm) \
		$(use_enable debug)
}

src_install(){
	default
	local i s="/usr/share/$PN"
	# forget issue about xpm, as not use xpm
#	sed -i -e 's:#000000:#3f7f7f:' -e 's:#424242:#1f3f3f:' -e 's:#444444:#3d7d7d:' -e 's:#aaaaaa:#1f3f3f:' -e 's:#888888:#0f1f1f:' "$D/$s"/img/*.xpm
	use xpm || rm "$D/$s/img" -Rf
	dodir "$s/examples"
	dosym "../usr/share/$PN/xkbd-small.conf" /etc/xkbd-config.conf
	mv "$D/$s"/*.xkbd "$D/$s/examples"
	for i in "$D/$s/$PN-"{config,onoff}; do
		dobin "$i"
		unlink "$i"
	done
}

EAPI=6

inherit eutils
SLOT=0
DESCRIPTION="Simple desktop layout"
LICENSE="*"
IUSE="abi_x86_32 abi_x86_64 +udev libnotify minimal bluetooth wifi +jpeg +tiff svg tint2 alsa laptop +dhcp"
# strict select
IUSE="$IUSE video_cards_i965 video_cards_r600 video_cards_radeonsi"
DEPEND="tint2? ( x11-misc/tint2 )
	>=x11-wm/openbox-3.5.0"
RDEPEND=" ${DEPEND}
	udev? ( virtual/udev net-fs/autofs )
	libnotify? ( x11-libs/libnotify )
	bluetooth? (
		net-wireless/bluez[test-programs]
		net-dialup/ppp
		net-misc/bridge-utils
	)
	wifi? ( net-wireless/iwd )
	media-libs/imlib2[png,jpeg?,tiff?]
	media-gfx/feh
	x11-misc/slock
	alsa? ( media-sound/alsa-utils )
	x11-apps/xfontsel
	x11-misc/xdg-utils
	x11-apps/xmodmap
	dhcp? (
		net-misc/dhcpcd
		net-dns/dnrd
	)
	laptop? (
		>=x11-misc/xkbd-0.8.17
	)
	!minimal? (
		!tint2? ( || (
		x11-misc/pcmanfm
		xfce-base/xfdesktop[thunar]
		gnome-base/nautilus
		x11-misc/spacefm
		) )
		|| ( media-gfx/imagemagick[png,jpeg?,tiff?,svg?] media-gfx/graphicsmagick[imagemagick,png,jpeg?,tiff?,svg?] )
		x11-wm/openbox[imlib,svg?]
		sys-apps/msr-tools
	)"
#	x11-apps/setxkbmap x11-apps/xkbcomp x11-apps/xrdb x11-apps/xwininfo x11-apps/xkill
#	opencl? (
#		video_cards_i965? (
#			abi_x86_32? ( dev-libs/beignet )
#			abi_x86_64? ( !abi_x86_32? ( dev-libs/intel-neo ) )
#		)
#		video_cards_r600? ( media-libs/mesa[opencl] )
#		video_cards_radeonsi? ( media-libs/mesa[opencl] )
#	)
KEYWORDS="~x86 ~amd64"
HOMEPAGE="https://github.com/mahatma-kaganovich/raw"

src_unpack(){
	mkdir -p "$S"
}

src_install(){
	local i s d="${D}/usr/share/ya-layout"
	cp -a "$FILESDIR"/* "${D}"/ || die
	rm -Rf `find "${D}" -name ".*"`
	chown root:root "${D}" -Rf
	chmod 755 "${D}"/usr/{bin,sbin,libexec/ya-layout}/* "${D}/usr/share/${PN}"/auto.cifs "${D}"/etc/X11/Sessions/*
	dosym 'cifs/*' /mnt/auto/smb
	if use udev; then
		dosym /mnt/auto/disk /usr/share/${PN}/Desktop/disk
	else
		rm "${D}/etc/udev" -Rf
	fi
	use jpeg || sed -i -e 's:jpg:tiff:g' "${D}"{/usr/bin/ob3menu,/etc/xdg/ya/menu.xml}
	use tiff || sed -i -e 's/tiff:-/miff:-/g' -e 's:tiff:png:g' "${D}"{/usr/bin/ob3menu,/etc/xdg/ya/menu.xml}
	use svg || sed -i -e 's: --svg::g' "${D}"/etc/xdg/ya/menu.xml
	if use tint2; then
		local items=TSE
		# hate effects & decorations - non-ergonomic for eyes
		# top-right is also faster
		{
		use wifi && items+=E && echo "
#---------
# execp wifi monitor
execp = new
execp_command = nice -1 bash /usr/share/ya-layout/iw.sh
execp_lclick_command = sudo -n /usr/sbin/ya-nrg wifi-restart
execp_rclick_command = /usr/bin/ya-session --run +/usr/bin/iwctl
execp_interval = 0
execp_continuous = 2
execp_font_color = #ffffff 100
execp_font = sans 12
#execp_padding = 1 8

"
		echo "
#---------
# execp ergonomic clock & battery
execp = new
execp_command = nice -1 perl /usr/share/ya-layout/clock-bat.pl
execp_interval = 0
execp_continuous = 2
execp_font_color = #ffffff 100
execp_font = sans 12
#execp_padding = 1 8

"
}|cat /etc/xdg/tint2/tint2rc - >"${D}"/etc/xdg/ya/tint2rc &&
		sed -i -e 's:777777:ffffff:' "${D}"/etc/xdg/ya/tint2rc &&
		for i in {task,bat1,bat2,time1,time2,tooltip,execp}'_font sans 12' 'panel_position top right horizontal' 'rounded 3' 'wm_menu 1' 'font_shadow 0' 'border_width 0' 'panel_padding 0 0 0' 'taskbar_padding 2 0 2' 'task_padding 0 0' 'panel_size 0 20' "panel_items $items" 'mouse_right none' 'mouse_middle maximize_restore' 'clock_padding 1 8' 'battery_padding 1 8' 'systray_padding 1 1 1' 'taskbar_name 0' 'disable_transparency 0' 'mouse_effects 0'; do
			grep -q "^${i%% *}\s*=" "${D}"/etc/xdg/ya/tint2rc || echo "${i/ / = }" >>"${D}"/etc/xdg/ya/tint2rc
			sed -i -e "s:^${i%% *} =.*\$:${i/ / = }:" "${D}"/etc/xdg/ya/tint2rc
		done
		cp "${D}"/etc/xdg/ya{,-minimal}/tint2rc
		i=0
		while read s; do
			case "$s" in
			background_color" "*)
				i=$((i+1))
				case $i in
				2)s="${s% *} 20";;
				3)s="${s% *} 40";;
				esac
			;;
			esac
			echo "$s"
		done <"${D}"/etc/xdg/ya/tint2rc >"${D}"/etc/xdg/ya/tint2rc.tmp
		rename .tmp '' "${D}"/etc/xdg/ya/tint2rc.tmp
		sed -e '/^[0-9a-z]*_font = /d' <"${D}"/etc/xdg/ya/tint2rc >"${D}"/etc/xdg/ya-minimal/tint2rc
		sed -i -e 's%YA_STARTUP:=XF86Desktop%YA_STARTUP:=TINT2%' "${D}"/usr/bin/ya-session
	else
		sed -i -e 's%YA_STARTUP:=TINT2%YA_STARTUP:=XF86Desktop%' "${D}"/usr/bin/ya-session
	fi
	sed -i -e 's:/lib\*/:/'"$(get_libdir)"'/:g' "${D}"/usr/bin/*
	use bluetooth || rm "$D/etc/ppp" -Rf
	use libnotify || sed -i -e 's:^notify=.*$:notify=:' "${D}"/usr/bin/*
	ewarn "Edit /etc/conf.d/autofs: MASTER_MAP_NAME=\"/usr/share/${PN}/auto.master\"
Then do: \"ya-session --layout [user]\" - to copy minimal Desktop/*
and, possible, restart [udev]"
	ewarn "remove XTerm.*background & XTerm.*foreground from .Xresources and use XTerm.*.reverseVideo instead"
	dodir /var/lib/ya
	touch "$D"/var/lib/ya/menu.xml
	use laptop && sed -i -e 's:--slow:--low 8x8 16x16 + HighContrast locolor Adwaita --slow:' "$D"/etc/xdg/ya/menu.xml
	for i in "${D}"/etc/xdg/ya/*.patch; do
		patch -Ntp1 -i "$i"  -d "$D"
	done
	rm "${D}"/etc/xdg/ya/*.{orig,rej,patch}
	ob3config_preinst=yes
}

pkg_postinst(){
	true
}

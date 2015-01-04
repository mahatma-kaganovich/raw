filterflag(){
local p v
for p in $* ; do
for v in LDFLAGS CFLAGS CPPFLAGS CXXFLAGS; do
	export $v="${!v// $p / }"
	export $v="${!v#$p }"
	export $v="${!v% $p}"
done
done
}

case "$PN" in
glibc)filterflag -Ofast -ffast-math -ftracer;;
sqlite|postgresql*|goffice|db)filterflag -Ofast -ffast-math;;
fontforge)filterflag -Ofast;;
mit-krb5|ceph)export CFLAGS="${CFLAGS//-Os/-O2}";export CXXFLAGS="${CXXFLAGS//-Os/-O2}";;
dirac|mpv)filterflag -fgraphite-identity;;
wine)filter-flags -ftree-loop-distribut*;;
ncurses)use profile && filter-flags -fomit-frame-pointer;;
esac

[ "${CFLAGS//-flto}" != "$CFLAGS" ] &&
case $CATEGORY/$PN in
app-arch/bzip2|net-libs/libpcap|sys-libs/ncurses|sys-libs/slang) export LDFLAGS="$LDFLAGS -fPIC" ;;
dev-lang/perl) export CFLAGS="$CFLAGS -fPIC" ;;
sys-kernel/*-sources|sys-devel/gcc|dev-lang/swig|dev-lang/orc|media-plugins/live|sys-fs/mtools|dev-libs/gmp|dev-libs/ppl|app-benchmarks/bashmark|media-sound/wavpack|net-dialup/rp-l2tp|net-misc/iputils|sys-apps/dbus|sys-apps/hdparm|sys-apps/pciutils|sys-apps/sysvinit|sys-fs/dosfstools|sys-fs/squashfs-tools|sys-process/procps|media-libs/lcms|media-libs/tiff|dev-libs/libcoyotl|media-video/dirac|dev-libs/libevocosm|media-libs/libdvdread|dev-libs/libusb|dev-libs/glib|media-libs/libmp4v2|dev-libs/dbus-glib|dev-libs/libpcre|net-libs/gnutls|app-antivirus/clamav|app-shells/bash|dev-db/unixODBC|dev-libs/libcdio|media-libs/flac|sys-apps/less|sys-devel/bc|sys-libs/gpm|net-print/cups|sys-devel/libtool) filterflag -flto ;;
dev-libs/icu)export CFLAGS="-w -pipe -O3 -march=native -fomit-frame-pointer";export CXXFLAGS="$CFLAGS";;
esac

[ "${USE//system-sqlite}" = "$USE" -a "${IUSE//system-sqlite}" != "$IUSE" ] && filterflag -Ofast -ffast-math


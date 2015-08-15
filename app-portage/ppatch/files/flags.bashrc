[ "$EBUILD_PHASE" = setup ] && {

filterflag(){
local p v x r=false
for p in $* ; do
for v in LDFLAGS CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS; do
	x="${!v}"
	x="${x// $p / }"
	x="${x#$p }"
	x="${x% $p}"
	[ "${!v}" = "$x" ] || {
		export $v="$x"
		r=true
	}
done
done
$r
}

appendflag(){
	local v
	for v in CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS LDFLAGS; do
		export $v="${!v} $*"
	done
}

_isflag(){
	local i f v f1
	for v in LDFLAGS CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS; do
		for f in ${!v}; do
			f1="${f%%=*}"
			for i in "${@}"; do
				[ "$i" = "$f" -o "$i" = "$f1" ] && return 0
			done
		done
	done
	return 1
}

_iuse(){
	local i
	for i in $IUSE; do
		if [ "$i" = "${1#!}" ]; then
			use $1
			return $?
		fi
	done
	return 0
}

gccve(){
	[[ "`LANG=C gcc -v 2>&1`" == *" version $1"* ]]
}

case "$PN" in
# libaio breaks others
mysql|mariadb|clamav|heimdal|glibc|lxc|qemu|elfutils|cvs|lksctp-tools|libreoffice|samba|pciutils|xfsprogs|numactl|ncurses)filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin;;&
libaio)_isflag -flto && export LDFLAGS="$LDFLAGS -fno-lto";;&
perl)_isflag -flto && export LDFLAGS="$LDFLAGS -fPIC";;&
glibc)filterflag -Ofast -ffast-math -ftracer;;
sqlite|postgresql*|goffice|db|protobuf|qtwebkit|webkit-gtk)filterflag -Ofast -ffast-math;;
fontforge)filterflag -Ofast;;
mit-krb5|ceph)export CFLAGS="${CFLAGS//-Os/-O2}";export CXXFLAGS="${CXXFLAGS//-Os/-O2}";;
wine)filterflag -ftree-loop-distribution -ftree-loop-distribute-patterns;;
ncurses)use profile && filterflag -fomit-frame-pointer;;
xf86-video-siliconmotion|vlc)appendflag -w;;
libX11|wget)_isflag -Os && _isflag -Ofast -ffast-math -funsafe-math-optimizations && ! _isflag -fno-unsafe-math-optimizations && appendflag -fno-unsafe-math-optimizations -fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math;;
cairo)[[ "$PV" == 1.12.16* ]] && appendflag -fno-lto;;
udev)filterflag -Wl,--sort-section=alignment;; # gold
# 5.1
gccxml|xemacs|devil|vtun|irda-utils|wmmon|bbrun|diffball|ldns|rp-l2tp)appendflag -std=gnu89;;
sessreg|ldns)export CPPFLAGS="$CPPFLAGS -P";;
mpg123)_iuse abi_x86_32 && gccve 5. && export CFLAGS="${CFLAGS//-O3/-O2}" && filterflag -Ofast -fpeel-loops -funroll-loops;;
xorg-server)appendflag -w;;
esac

#[ "${CFLAGS//-flto}" != "$CFLAGS" ] &&
#case $CATEGORY/$PN in
#sys-kernel/*-sources|sys-devel/gcc|dev-lang/swig|dev-lang/orc|media-plugins/live|sys-fs/mtools|dev-libs/gmp|dev-libs/ppl|app-benchmarks/bashmark|media-sound/wavpack|net-dialup/rp-l2tp|net-misc/iputils|sys-apps/dbus|sys-apps/hdparm|sys-apps/pciutils|sys-apps/sysvinit|sys-fs/dosfstools|sys-fs/squashfs-tools|sys-process/procps|media-libs/lcms|media-libs/tiff|dev-libs/libcoyotl|media-video/dirac|dev-libs/libevocosm|media-libs/libdvdread|dev-libs/libusb|dev-libs/glib|media-libs/libmp4v2|dev-libs/dbus-glib|dev-libs/libpcre|net-libs/gnutls|app-antivirus/clamav|app-shells/bash|dev-db/unixODBC|dev-libs/libcdio|media-libs/flac|sys-apps/less|sys-devel/bc|sys-libs/gpm|net-print/cups|sys-devel/libtool) filterflag -flto ;;
#dev-libs/icu)export CFLAGS="-w -pipe -O3 -march=native -fomit-frame-pointer";export CXXFLAGS="$CFLAGS";;
#esac

_iuse !system-sqlite && filterflag -Ofast -ffast-math
_iuse gold && filterflag -Wl,--sort-section=alignment

}

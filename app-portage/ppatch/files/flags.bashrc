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
	for v in CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS; do
		export $v="${!v} $*"
	done
}

appendflag1(){
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
				[[ "$f" == $i || "$f1" == $i ]] && return 0
			done
		done
	done
	return 1
}

filterflag2(){
	local i f v f1 f2="$1" v1 ff r=false
	shift
	for v in LDFLAGS CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS; do
		v1=
		ff=
		for f in ${!v}; do
			f1="${f%%=*}"
			for i in "${@}"; do
				[[ "$f" == $i || "$f1" == $i ]] && ff+=" $f" && continue 2
			done
			v1+=" $f"
		done
		[ -z "$ff" ] && {
			[ $v = CFLAGS ] && break
			continue
		}
		export $v="${v1# }"
		for i in $f2; do
				[ -n "${!i}" ] && export $i="${!i}$ff"
		done
		r=true
	done
	$r
}

_iuse(){
	local i
	for i in $IUSE; do
		if [ "$i" = "${1#!}" ]; then
			use $1
			return $?
		fi
	done
	return 1
}

gccve(){
	[[ "`LANG=C gcc -v 2>&1`" == *" version $1"* ]]
}

filter86_32(){
#	[ -n "$CFLAGS_x86" ] || return # keep for main abi for testing
	_iuse abi_x86_32 || return
	filterflag2 'CFLAGS_amd64 CFLAGS_x32' "${@}"
}

case "$PN" in
xemacs)_isflag -flto && {
	ldf=' '
	filterflag2 ldf '-Wl,*'
	export LDFLAGS="${ldf# }"
};;&
# libaio breaks others
# gtkmm too (cdrdao)
php|qtwebkit|xf86-video-intel|mplayer|gtkmm|mysql|mariadb|clamav|heimdal|glibc|lxc|qemu|elfutils|cvs|lksctp-tools|libreoffice|samba|pciutils|xfsprogs|numactl|ncurses|alsa-lib)filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin;;&
glibc)_isflag -fno-omit-frame-pointer && filterflag -f{,no-}omit-frame-pointer;;& # 2.23
ilmbase)_isflag -flto && export LDFLAGS="$LDFLAGS -lpthread";;& # openexr
libaio|qtscript)_isflag -flto && export LDFLAGS="$LDFLAGS -fno-lto";;&
cdrdao|gcr|ufraw|gdal|dosemu|xemacs|soxr|flac|libgcrypt)filterflag2 '' -flto;;&
boost)filter86_32 '-flto*' '-*-lto-*' -fuse-linker-plugin;;&
perl)_isflag -flto && export LDFLAGS="$LDFLAGS -fPIC";;&
cmake)_isflag -flto && _isflag '-floop-*' '-fgraphite*' && filterflag -fipa-pta;;&
ceph)_isflag -fipa-pta || filterflag '-floop-*';;&
ceph)_isflag '-floop-*' '-fgraphite*' && { # prefer graphite vs. lto
	# handle lto <-> no-lto transition
	if filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin; then
		appendflag1 -fPIC
	elif gcc -v 2>&1 |grep -q enable-lto; then
		appendflag1 -fno-lto
	fi
}
;;&
glibc)filterflag -Ofast -ffast-math -ftracer -fopenmp -fopenmp-simd;;
sqlite|postgresql*|goffice|db|protobuf|qtwebkit|webkit-gtk|python|guile)filterflag -Ofast -ffast-math;;
fontforge)filterflag -Ofast;;
mit-krb5|ceph)export CFLAGS="${CFLAGS//-Os/-O2}";export CXXFLAGS="${CXXFLAGS//-Os/-O2}";;
wine)filterflag -ftree-loop-distribution -ftree-loop-distribute-patterns;;
ncurses)_iuse profile && filterflag -fomit-frame-pointer;;
xf86-video-siliconmotion|vlc)appendflag -w;;
libX11|wget)_isflag -Os && _isflag -Ofast -ffast-math -funsafe-math-optimizations && ! _isflag -fno-unsafe-math-optimizations && appendflag -fno-unsafe-math-optimizations -fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math;;
cairo)[[ "$PV" == 1.12.16* ]] && appendflag1 -fno-lto;;
udev)filterflag -Wl,--sort-section=alignment;; # gold
fltk)_isflag '-floop-*' '-fgraphite*' && filterflag -ftree-loop-distribution;; # -O2+
freeglut)_isflag '-floop-*' '-fgraphite*' && appendflag -fno-ipa-cp-clone;;
opus)
	filterflag -Ofast -ffast-math
#	export enable_float_approx=yes
;;
# 5.1
gccxml|xemacs|devil|vtun|irda-utils|wmmon|bbrun|diffball|ldns|rp-l2tp)appendflag -std=gnu89;;
sessreg|ldns)export CPPFLAGS="$CPPFLAGS -P";;
mpg123)_iuse abi_x86_32 && gccve 5. && export CFLAGS="${CFLAGS//-O3/-O2}" && filterflag -Ofast -fpeel-loops -funroll-loops;;
xorg-server)appendflag -w;;
klibc)[[ "$MAKEOPTS" == *'-j '* || "$MAKEOPTS" == *-j ]] && export MAKEOPTS="$MAKEOPTS -j8";;
gmp)filterflag -floop-nest-optimize;;
sarg)filterflag -w;;
ffmpeg|libav)_iuse abi_x86_32 && filterflag -fno-omit-frame-pointer;; # x86 mmx -Os
esac

#[ "${CFLAGS//-flto}" != "$CFLAGS" ] &&
#case $CATEGORY/$PN in
#sys-kernel/*-sources|sys-devel/gcc|dev-lang/swig|dev-lang/orc|media-plugins/live|sys-fs/mtools|dev-libs/gmp|dev-libs/ppl|app-benchmarks/bashmark|media-sound/wavpack|net-dialup/rp-l2tp|net-misc/iputils|sys-apps/dbus|sys-apps/hdparm|sys-apps/pciutils|sys-apps/sysvinit|sys-fs/dosfstools|sys-fs/squashfs-tools|sys-process/procps|media-libs/lcms|media-libs/tiff|dev-libs/libcoyotl|media-video/dirac|dev-libs/libevocosm|media-libs/libdvdread|dev-libs/libusb|dev-libs/glib|media-libs/libmp4v2|dev-libs/dbus-glib|dev-libs/libpcre|net-libs/gnutls|app-antivirus/clamav|app-shells/bash|dev-db/unixODBC|dev-libs/libcdio|media-libs/flac|sys-apps/less|sys-devel/bc|sys-libs/gpm|net-print/cups|sys-devel/libtool) filterflag -flto ;;
#dev-libs/icu)export CFLAGS="-w -pipe -O3 -march=native -fomit-frame-pointer";export CXXFLAGS="$CFLAGS";;
#esac

_iuse !system-sqlite && filterflag -Ofast -ffast-math
_iuse gold && filterflag -Wl,--sort-section=alignment

filter86_32 -fschedule-insns -fira-loop-pressure

}

[ "$EBUILD_PHASE" = setup ] && {

# dumb names to avoid collisions

_iuse(){
	local i
	for i in $USE; do
		[ "$i" = "$1" ] && return 0
	done
	# [sometimes] broken
	for i in $IUSE; do
		[ "~$i" = "$1" ] && return 0
		if [ "$i" = "${1#!}" ]; then
			use $1
			return $?
		fi
	done
	return 1
}

filterflag1(){
local p v x local f ff="$1" rr
shift
for v in $ff; do
    rr=
    x=
    for f in ${!v}; do
	for p in $* ; do
		[[ "$f" == $p ]] && rr+=" $f" && continue 2
	done
	x+=" $f"
    done
    x="${x# }"
    [ "$x" != "${!v}" ] && export $v="$x"
    [ -n "$rr" ] && echo "flags filtered $v $rr"
done
$r
}

filterflag(){
	filterflag1 'LDFLAGS CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS' "${@}"
}

filterldflag(){
	local i="$LDFLAGS"
	LDFLAGS=
	for i in $i; do
		[[ "$i" == -Wl* ]] && LDFLAGS+=" $i" || echo "flag filtered LDFLAGS $i"
	done
	export LDFLAGS="${LDFLAGS# }"
}

appendflag(){
	local v
	for v in CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS; do
		export $v="${!v} $*"
	done
	echo "flag appended [CF]*FLAGS $*"
}

appendflag1(){
	local v
	for v in CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS LDFLAGS; do
		export $v="${!v} $*"
	done
	echo "flag appended [CFL]*FLAGS $*"
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

gccve(){
	[[ "`LANG=C gcc -dumpversion`" == $1* ]]
}

filter86_32(){
#	[ -n "$CFLAGS_x86" ] || return # keep for main abi for testing
	_iuse abi_x86_32 || return
	filterflag2 'CFLAGS_amd64 CFLAGS_x32' "${@}"
}

filter_cf(){
	local i c="$1" v="$2" vv v1 ff=
	[ -z "${!c}" ] && return
	vv="${v}_${c}"
	v1="${!vv}"
	[ -z "$v1" ] && {
		for i in ${!v}; do
			echo 'int main(){}' |${!c} -x $3 - -pipe $i -o /dev/null >/dev/null 2>&1 && v1+=" $i" || ff+=" $i"
		done
		[ -n "$ff" ] && {
			echo "filtered $v ${!c}$ff"
			# -flto
			filterflag1 LDFLAGS $ff
		}
		v1="${v1# }"
		export ${vv}="$v1"
	}
	export ${v}="${!vv}"
}

_fLTO(){
	_isflag -flto '-flto=*'
}

_fLTO_f(){
	_fLTO || return 1
	appendflag1 "${@}"
	export LDFLAGS="$* $LDFLAGS"
}

filter_cf CC CFLAGS c
filter_cf CXX CXXFLAGS c++

case "$PN" in
quota|xinetd|samba|python) _iuse !rpc || [ -e /usr/include/rpc/rpc.h ] || {
	# python - only if libnsl present (module nis)
	export CFLAGS="$CFLAGS $(pkg-config libtirpc --cflags-only-I)"
	export CXXFLAGS="$CXXFLAGS $(pkg-config libtirpc --cflags-only-I)"
	export LDFLAGS="$LDFLAGS $(pkg-config libtirpc --libs)"
}
;;&
xemacs)_fLTO && {
	ldf=' '
	filterflag2 ldf '-Wl,*'
	export LDFLAGS="${ldf# }"
};;&
# libaio breaks others
# gtkmm too (cdrdao)
# fuse: e2fsprogs failed only on gcc 8.2
# ffmpeg: amd64 - mp4 crushes
ffmpeg|xemacs|mesa|fuse|wayland|privoxy|icedtea|qtwebkit|xf86-video-intel|mplayer|mysql|heimdal|glibc|cvs|pulseaudio|lynx)filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin -fdevirtualize-at-ltrans;;&
ncurses)_fLTO && export ac_cv_func_dlsym=no ac_cv_lib_dl_dlsym=yes;;&
libreoffice|mariadb)filterflag -ffat-lto-objects;;&
mariadb)_fLTO_f -fno-ipa-cp-clone;;&
php)[[ "$PV" == 5.* ]] || filterflag '-flto*' -fdevirtualize-at-ltrans;;&
# works over make.lto wrapper, but wrapper wrong for some other packets
numactl|alsa-lib|elfutils|dhcdrop|lksctp-tools|mysql-connector-c)filterflag '-flto*' -fdevirtualize-at-ltrans;;&
# ilmbase -> openexr
ilmbase|mesa)_fLTO_f -Wl,-lpthread -lpthread;;&
clang*)filterflag -flto-partition=none;;&
glibc)filterflag -mfpmath=387;;&
glibc)_isflag -fno-omit-frame-pointer && filterflag -f{,no-}omit-frame-pointer;;& # 2.23
libaio|qtscript)_fLTO && export LDFLAGS="$LDFLAGS -fno-lto";;&
cdrdao|gcr|ufraw|gdal|dosemu|soxr|flac|libgcrypt)filterflag2 '' '-flto*';;&
boost)filter86_32 '-flto*' '-*-lto-*' -fuse-linker-plugin -fdevirtualize-at-ltrans;;&
elogind|perl|autofs|dovecot)_fLTO && export LDFLAGS="$LDFLAGS -fPIC";;&
cmake)_fLTO && _isflag '-floop-*' '-fgraphite*' && filterflag -fipa-pta;;&
ceph)_isflag '-floop-*' '-fgraphite*' && { # prefer graphite vs. lto
	# handle lto <-> no-lto transition
	if filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin; then
		appendflag1 -fPIC
	elif gcc -v 2>&1 |grep -q enable-lto; then
		appendflag1 -fno-lto
	fi
}
;;&
glibc)gccve 6. && appendflag -fno-tree-slp-vectorize;;&
glibc)gccve 6. || filterflag -ftracer;;&
glibc)filterflag -Ofast -ffast-math -fopenmp -fopenmp-simd '-*parallelize*';;&
sqlite|postgresql*|goffice|db|protobuf|qtwebkit|qtwebengine|webkit-gtk|python|guile|chromium*|rrdtool)filterflag -Ofast -ffast-math;;&
chromium*)_iuse abi_x86_32 && filterflag -maccumulate-outgoing-args;;&
fontforge)filterflag -Ofast;;
mit-krb5|ceph)export CFLAGS="${CFLAGS//-Os/-O2}";export CXXFLAGS="${CXXFLAGS//-Os/-O2}";;
wine)filterflag -ftree-loop-distribution -ftree-loop-distribute-patterns;;
ncurses)_iuse profile && filterflag -fomit-frame-pointer;;
xf86-video-siliconmotion|vlc|xorg-server)appendflag -w;;
libX11|wget)_isflag -Os && _isflag -Ofast -ffast-math -funsafe-math-optimizations && ! _isflag -fno-unsafe-math-optimizations && appendflag -fno-unsafe-math-optimizations -fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math;;
cairo)[[ "$PV" == 1.12.16* ]] && appendflag1 -fno-lto;;
udev|spidermonkey)filterflag -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads;; # gold
fltk)_isflag '-floop-*' '-fgraphite*' && filterflag -ftree-loop-distribution;; # -O2+
freeglut)_isflag '-floop-*' '-fgraphite*' && appendflag -fno-ipa-cp-clone;;
# 5.1
gccxml|xemacs|devil|vtun|irda-utils|wmmon|bbrun|diffball|ldns|rp-l2tp)appendflag -std=gnu89;;
sessreg|ldns)export CPPFLAGS="$CPPFLAGS -P";;
mpg123)_iuse abi_x86_32 && gccve 5. && export CFLAGS="${CFLAGS//-O3/-O2}" && filterflag -Ofast -fpeel-loops -funroll-loops;;&
klibc)[[ "$MAKEOPTS" == *'-j '* || "$MAKEOPTS" == *-j ]] && export MAKEOPTS="$MAKEOPTS -j8";;
gmp)filterflag -floop-nest-optimize;;
gmp) _isflag '-floop-*' && {
	filterflag -floop-unroll-and-jam
	appendflag -fno-loop-unroll-and-jam
};;
sarg)filterflag -w;;
criu)filterldflag;filterflag -maccumulate-outgoing-args '-flto=*';;
ffmpeg|libav)_iuse abi_x86_32 && filterflag -fno-omit-frame-pointer;; # x86 mmx -Os
faad2|openssl|patch)gccve 5. && filterflag -floop-nest-optimize;;
geos|readahead-list|thin-provisioning-tools|libprojectm|gtkmathview|qtfm|qtgui|qtwebkit)gccve 6. && export CXXFLAGS="$CXXFLAGS -std=gnu++98";;
ruby)filterflag -funroll-loops -fweb;;
ghostscript-gpl)filterflag -mmitigate-rop;; # ????!
compiler-rt)__clang=clang;filter_cf __clang CFLAGS c;filter_cf __clang CXXFLAGS c++;filter_cf __clang LDFLAGS c++;;
easystroke)export CXXFLAGS="$CXXFLAGS -fno-ipa-cp-clone";export LDFLAGS="$LDFLAGS -lglib-2.0";;
potrace)appendflag -fno-tree-slp-vectorize;;
groff)filterflag -fisolate-erroneous-paths-attribute;;
coreutils)filterflag -flto=jobserver && appendflag1 -flto;;
# qtcore -> qtxml
glibc|gnustep-back-cairo|qtcore)_fLTO_f -flto-partition=none;;
mpg123)filterflag -floop-nest-optimize;; # distortion on sse
mongodb)[ "$AR" = gcc-ar ] && export AR=/usr/bin/ar ;;
esac

# more test flags-inject.bashrc before remove
# seamonkey unknown error on install -> precompile cache
_iuse !system-sqlite && filterflag -Ofast -ffast-math

(_iuse gold || [[ "$LD" == *gold ]] || _isflag -fuse-ld=gold) &&
	filterflag -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads
(_iuse clang || [[ "$LD" == *lld ]] || _isflag -fuse-ld=lld) &&
	filterflag -Wl,--reduce-memory-overheads
# 2do: find bad -O3 flags for seamonkey
#_iuse custom-optimization && filterflag -Ofast -O3


#filter86_32 -fschedule-insns -fira-loop-pressure

}


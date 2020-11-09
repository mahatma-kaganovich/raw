[ "$EBUILD_PHASE" = setup ] && {

# dumb names to avoid collisions

_iuse(){
	local i
	for i in $USE; do
		[[ "$i" == "$1" ]] && return 0
	done
	# [sometimes] broken
	for i in $IUSE; do
		[[ "~$i" == "$1" ]] && return 0
		if [[ "$i" == "${1#!}" ]]; then
			use $1
			return $?
		fi
	done
	return 1
}

filterflag_(){
local p v x local f ff="$1" rr r=false
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
    [ -n "$rr" ] && r=true && echo "flags filtered $v $rr"
done
$r
}

filterflag(){
	filterflag_ 'LDFLAGS CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS' "${@}"
}

filterflag1(){
	die 'flags.bashrc renamed filterflag1 to filterflag_'
}

filterldflag(){
	local i="$LDFLAGS"
	LDFLAGS=
	for i in $i; do
		[[ "$i" == -Wl* ]] && LDFLAGS+=" $i" || echo "flag filtered LDFLAGS $i"
	done
	export LDFLAGS="${LDFLAGS# }"
}

appendflag_(){
	local v ff="$1"
	shift
	for v in $ff; do
		export $v="${!v} $*"
	done
	ff="${ff//FLAGS}"
	[[ "$ff" == *' '* ]] && ff="{${ff// /,}}"
	echo "flag appended ${ff}FLAGS $*"
}

appendflag(){
	appendflag_ 'CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS' "${@}"
}

appendflag1(){
	appendflag_ 'CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS LDFLAGS' "${@}"
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
	[[ "`LANG=C ${CC:-gcc} -dumpversion`" == $1* ]]
}

filter86_32(){
#	[ -n "$CFLAGS_x86" ] || return # keep for main abi for testing
	_iuse abi_x86_32 || return
	filterflag2 'CFLAGS_amd64 CFLAGS_x32' "${@}"
}

filter_cf(){
	local i c="$1" v="$2" vv v1 ff= l=
	[ -z "${!c}" ] && return
	vv="${v}_${c}"
	v1="${!vv}"
	[ "$v" = LDFLAGS ] || l="$LDFLAGS "
#	echo 'int main(){}' |${!c} -x $3 $l-Werror - -w -pipe $i -o /dev/null && l+='-Werror '
	[ -z "$v1" ] && {
		for i in ${!v}; do
			echo 'int main(){}' |${!c} -x $3 $l$v1 - -w -pipe $i -o /dev/null && v1+=" $i" || ff+=" $i"
		done
		[ -n "$ff" ] && {
			echo "filtered $v ${!c}$ff"
			# -flto
#			filterflag_ LDFLAGS $ff
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

_fnofastmath(){
	# "simple" -fno-fast-math
	# respect -Ofast != '-O3 -ffast-math'
	# -mfpmath=both sometimes benefits only fast
	# compat: with my profiles only 'isflag && append' enough
	local v f="${CFLAGS_FAST_MATH:--ffast-math}" nf="${CFLAGS_NO_FAST_MATH:--O3 -Ofast -fno-fast-math}"
	[ -n "$*" ] && nf="${nf//-fno-fast-math/$*}"
	filterflag ${f//-Ofast} -mfpmath=both
#	filterflag '-mfpmath=sse?387' '-mfpmath=387?sse'
	for v in CFLAGS CPPFLAGS CXXFLAGS FFLAGS FCFLAGS LDFLAGS; do
		[[ "${!v##*-O}" == fast* ]] && export $v="${!v//-Ofast/$nf}"
	done
}

_filtertst(){
filter_cf CC LDFLAGS c
filter_cf CC CFLAGS c
filter_cf CXX CXXFLAGS c++
_iuse clang && {
	CC=clang filter_cf CC LDFLAGS c
	CC=clang filter_cf CC CFLAGS c
	CXX=clang++ filter_cf CXX CXXFLAGS c++
}
}

_filtertst

_test_f="$CFLAGS/$CXXFLAGS/$LDFLAGS"
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
# libbsd: mailx
sandbox|valgrind|xf86-video-intel|libwacom|libbsd|dcc|chromium*|webkit-gtk|ffmpeg|xemacs|fuse|privoxy|icedtea|openjdk|qtwebkit|mplayer|mysql|heimdal|glibc|cvs|pulseaudio)
#	${CC:-gcc} -v 2>&1|grep -q "^gcc version" &&
		filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin -fdevirtualize-at-ltrans
;;&
libaio)_fLTO_f -fno-lto;;&
qtscript)filterflag -flto '-flto=*' && appendflag_ LDFLAGS -flto;;
gnustep-base|gnustep-back-cairo)_fLTO_f -flto-partition=1to1;;&
#openjdk)_fLTO_f -fno-strict-aliasing -flto;;& # ulimit -n 100000
dovecot)
	filterflag -ffat-lto-objects # speedup build
#	_isflag -fuse-linker-plugin && appendflag1 -fno-use-linker-plugin
	_isflag -fuse-linker-plugin && appendflag1 -fno-strict-aliasing -flto-partition=one # or none
	export with_libunwind=no
	export enable_assert=no
;;&
gcc)
	# multi-version case
	_iuse lto || filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin -fdevirtualize-at-ltrans
	_iuse graphite || filterflag -floop-nest-optimize -floop-parallelize-all
	_iuse openmp || filterflag -fopenmp -fopenmp-simd -fopenacc -fgnu-tm
	filterflag --param=ipcp-unit-growth=1 && appendflag -fno-ipa-cp-clone
;;&
# while found affected only mongodb - at least no connect from UniFi (exception)
# looks like unwinding not required for anymore exclude debugging / verbose exceptions
# ps ceph too...
gcc|mongodb|mongo-tools|ceph|tigervnc)filterflag -fno-asynchronous-unwind-tables -Wl,--no-ld-generated-unwind-info -Wl,--no-eh-frame-hdr;;&
libreoffice)filterflag -Wl,--no-eh-frame-hdr;;&
# libX11 1) not build lto 2) w/o lto - moz segfault
doxygen|mongodb|libX11|llvm|clang)filterflag -fopenacc;;&
gcc|glibc|chromium|texlive-core|xemacs)filterflag -fopenmp -fopenmp-simd -fopenacc -fgnu-tm '-ftree-parallelize-loops*';;&
ipmitool|distcc|vlc|android-tools)appendflag -fcommon;;&
zstandard)export MAKEOPTS=-j1;;&
ncurses-compat|ncurses)_fLTO && export ac_cv_func_dlsym=no ac_cv_lib_dl_dlsym=yes;;&
inkscape|libreoffice|mariadb|nodejs|clang)filterflag -ffat-lto-objects;;&
mariadb)filterflag -fno-asynchronous-unwind-tables;;&
mariadb)_fLTO_f -fno-ipa-cp-clone;;&
php)[[ "$PV" == 5.* ]] || filterflag '-flto*' -fdevirtualize-at-ltrans;;&
# works over make.lto wrapper, but wrapper wrong for some other packets
numactl|alsa-lib|elfutils|dhcdrop|lksctp-tools|mysql-connector-c)filterflag '-flto*' -fdevirtualize-at-ltrans;;&
# ilmbase -> openexr
ilmbase)_fLTO_f -Wl,-lpthread -lpthread;;&
#clang*)filterflag -flto-partition=none;;&
glibc)filterflag -mfpmath=387;;&
glibc)_isflag -fno-omit-frame-pointer && filterflag -f{,no-}omit-frame-pointer;;& # 2.23
cdrdao|gcr|ufraw|_gdal|dosemu|soxr|flac|libgcrypt)filterflag2 '' '-flto*';;&
boost)filter86_32 '-flto*' '-*-lto-*' -fuse-linker-plugin -fdevirtualize-at-ltrans;;&
libsodium|elogind|perl|autofs|dovecot)_fLTO && appendflag_ LDFLAGS -fPIC;;&
cmake)_fLTO && _isflag '-floop-*' '-fgraphite*' && filterflag -fipa-pta;;&
# x86 gcc graphite ice
gmp)filterflag -fno-move-loop-invariants;;&
# mpg123 distortion on sse
mjpegtools|gmp|mpg123)filterflag -floop-nest-optimize -floop-parallelize-all;;&
bcrypt)_fLTO && appendflag -fno-loop-nest-optimize;;& # x86_32
bash)filterflag -fipa-pta;;&
ceph)
#	_isflag -floop-nest-optimize && 
	{ # prefer graphite vs. lto
	# handle lto <-> no-lto transition
	if filterflag '-flto*' '-*-lto-*' -fuse-linker-plugin; then
		appendflag1 -fPIC
	elif ${CC:-gcc} -v 2>&1 |grep -q enable-lto; then
		appendflag1 -fno-lto
	fi
}
;;&
glibc)gccve 6. || filterflag -ftracer;;&
glibc)filterflag -fopenmp -fopenmp-simd;;&
# -Ofast / -ffast-math:
# nodejs -> chromium
coreutils|groff|glibc|mpg123|nodejs|fontforge|sqlite|postgresql*|goffice|db|protobuf|qtwebkit|qtwebengine|webkit-gtk|python|guile|chromium*|rrdtool)_fnofastmath;;&
# sometimes somewere
#libX11|wget)_isflag -Os && _fnofastmath -fno-unsafe-math-optimizations -fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math;;&
chromium*)_iuse abi_x86_32 && filterflag -maccumulate-outgoing-args;;&
mit-krb5|ceph)export CFLAGS="${CFLAGS//-Os/-O2}";export CXXFLAGS="${CXXFLAGS//-Os/-O2}";;
wine)filterflag -ftree-loop-distribution -ftree-loop-distribute-patterns;;
ncurses)_iuse profile && filterflag -fomit-frame-pointer;;
xf86-video-siliconmotion|vlc|xorg-server)appendflag -w;;
cairo)[[ "$PV" == 1.12.16* ]] && appendflag1 -fno-lto;;
udev|spidermonkey)filterflag -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads;; # gold
fltk)_isflag '-floop-*' '-fgraphite*' && filterflag -ftree-loop-distribution;; # -O2+
freeglut)_isflag '-floop-*' '-fgraphite*' && appendflag -fno-ipa-cp-clone;;
# 5.1
gccxml|xemacs|devil|vtun|irda-utils|wmmon|bbrun|diffball|ldns|rp-l2tp)appendflag -std=gnu89;;
sessreg|ldns)appendflag_ CPPFLAGS -P;;
klibc)[[ "$MAKEOPTS" == *'-j '* || "$MAKEOPTS" == *-j ]] && export MAKEOPTS="$MAKEOPTS -j8";;
sarg)filterflag -w;;
criu)filterldflag;filterflag -maccumulate-outgoing-args '-flto=*';;
ffmpeg|libav)_iuse abi_x86_32 && filterflag -fno-omit-frame-pointer;; # x86 mmx -Os
ruby)filterflag -funroll-loops -fweb;;
ghostscript-gpl)filterflag -mmitigate-rop;; # ????!
compiler-rt)__clang=clang;filter_cf __clang CFLAGS c;filter_cf __clang CXXFLAGS c++;filter_cf __clang LDFLAGS c++;;
easystroke)appendflag_ CXXFLAGS -fno-ipa-cp-clone;appendflag_ LDFLAGS -lglib-2.0;;
potrace)appendflag -fno-tree-slp-vectorize;;
groff)filterflag -fisolate-erroneous-paths-attribute;;
coreutils)filterflag -flto=jobserver && appendflag1 -flto;;
# qtcore -> qtxml
glibc|_qtcore)_fLTO_f -flto-partition=none;;
mongodb)[ "$AR" = gcc-ar ] && export AR=/usr/bin/ar ;;
openssl)filterflag -ffast-math;; # 1.1.1 make
seamonkey|thunderbird|rsync)export LDFLAGS="${LDFLAGS//-Wl,--strip-all/-Wl,--strip-debug}";;&
# -> postgis
protobuf)filterflag -mtls-dialect=gnu2;;&
 # nss: gcc 10 mozilla broken ssl
nss)_iuse abi_x86_32 && gccve '[0-9][0-9]' && appendflag -fno-tree-slp-vectorize;;&
# hard to figure out
geos)_fnofastmath;filterflag -ffast-math -Ofast -Wl,--no-eh-frame-hdr;;&
esac

#case "$CATEGORY" in
# don't want to find problems here
#sci-libs|sci-geosciences)
#sci-*)_fnofastmath;;&
#esac

# more test flags-inject.bashrc before remove
# seamonkey unknown error on install -> precompile cache
_iuse !system-sqlite && _fnofastmath

(_iuse gold || [[ "$LD" == *gold ]] || _isflag -fuse-ld=gold) &&
	filterflag -Wl,--sort-section=alignment -Wl,--reduce-memory-overheads
(_iuse clang || [[ "$LD" == *lld ]] || _isflag -fuse-ld=lld) &&
	filterflag -Wl,--reduce-memory-overheads -Wl,--no-ld-generated-unwind-info


#filter86_32 -fschedule-insns -fira-loop-pressure

# clang too related from -flto, etc - filter twice
[ "$_test_f" = "$CFLAGS/$CXXFLAGS/$LDFLAGS" ] || _filtertst
[[ " $CFLAGS " == *\ -flto[\ =]* ]] && filterflag -Wa,--reduce-memory-overheads

}


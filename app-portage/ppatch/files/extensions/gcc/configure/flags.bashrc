#BOOT_CFLAGS=
f=-O2
if [ -n "$BOOT_CFLAGS" ]; then
	true
elif is-flagq -O3 || is-flagq -Ofast; then
	with_build_config+=' bootstrap-O3' # ignored
	f=-O3
elif ! is-flagq -O2 && is-flagq -O1; then
	with_build_config+=' bootstrap-O1' # ignored
	f=-O1
fi
filter-flags '-O*'
(is-flagq -flto || is-flagq '-flto=*') && {
	is-flagq -fuse-linker-plugin && with_build_config+=' bootstrap-lto' || with_build_config+=' bootstrap-lto-noplugin'
}
[[ " $IUSE " == *' mpx '* ]] && use mpx && with_build_config+=' bootstrap-mpx'
[ -n with_build_config ] && export with_build_config="${with_build_config# }"

#filter-flags -flto '-flto=*' -fuse-linker-plugin '*-lto-*'
filter-flags '-flto*' -fuse-linker-plugin '*-lto-*'

setup-allowed-flags
[ -n "$ALLOWED_FLAGS" ] && {
ALLOWED_FLAGS_=( ${ALLOWED_FLAGS[@]} -fmodulo-sched -mtls-dialect )
export ALLOWED_FLAGS_
setup-allowed-flags(){
	ALLOWED_FLAGS=( ${ALLOWED_FLAGS_[@]} )
}
export -f setup-allowed-flags
}

#i="$CXXFLAGS"
#strip-flags
#strip-flags(){ true;}
#export -f strip-flags

gcc_do_filter_flags || die
gcc_do_filter_flags(){ true;}
export -f gcc_do_filter_flags
#CXXFLAGS="$i"

# $f -> $CFLAGS -> $BOOT_FLAGS
for i in {C,CXX,LD,F,FC}FLAGS; do
	export $i="$f ${!i}"
done


#BOOT_CFLAGS+=" $CXXFLAGS"
#BOOT_LDFLAGS="$LDFLAGS"
#BOOT_ADAFLAGS

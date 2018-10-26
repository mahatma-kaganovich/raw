if is-flagq -O3 || is-flagq -Ofast; then
	with_build_config+=' bootstrap-O3'
	filter-flags '-O*'
elif is-flagq -O2; then
	true
elif is-flagq -O1; then
	with_build_config+=' bootstrap-O1'
	filter-flags '-O*'
fi
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
strip-flags
strip-flags(){ true;}
export -f strip-flags
#CXXFLAGS="$i"


#filter-flags "-flto*" "-lto-"
#BOOT_CFLAGS="$CXXFLAGS"
#BOOT_LDFLAGS="$LDFLAGS"
#BOOT_ADAFLAGS

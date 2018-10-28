#BOOT_CFLAGS=
ff=$(echo {CXX,LD,F,FC,GOC,LIBC,T,C}FLAGS)
f=-O2
if [ -n "$BOOT_CFLAGS" ]; then
	true
elif is-flagq -Ofast; then
	with_build_config+=' bootstrap-O3' # ignored
#	f="-O3$CFLAGS_FAST$CFLAGS_M"
	f="-O3"
elif is-flagq -O3; then
	with_build_config+=' bootstrap-O3' # ignored
	f=-O3
elif ! is-flagq -O2 && is-flagq -O1; then
	with_build_config+=' bootstrap-O1' # ignored
	f=-O1
elif ! is-flagq '-O*'; then
	append-flags $f
	append-ldflags $f
fi
# static libs
f1=
# other
f2=
replace-flags '-O*' $f
(is-flagq -flto || is-flagq '-flto=*') && {
	is-flagq -fuse-linker-plugin && with_build_config+=' bootstrap-lto' || with_build_config+=' bootstrap-lto-noplugin'
	replace-flags '-flto=*' -flto=jobserver
	replace-flags -flto -flto=jobserver
	filter-flags -ffat-lto-objects
	filter-ldflags -ffat-lto-objects
	f1+=' -flto=jobserver -fuse-linker-plugin -ffat-lto-objects'
	f2+=' -flto=jobserver -fuse-linker-plugin -fno-fat-lto-objects'
}
[[ " $IUSE " == *' mpx '* ]] && use mpx && with_build_config+=' bootstrap-mpx'
[ -n with_build_config ] && export with_build_config="${with_build_config# }"
filter-flags -ffast-math

# can filter or not here: custom cflags or not
#gcc_do_filter_flags || die
for i in $ff; do
	export ${i}_FOR_TARGET="${!i:-$CFLAGS} $f$f1"
	export $i="${!i:-$CFLAGS} $f$f2"
	for j in '' ; do
		export STAGE${j}_${i}="${!i}"
	done
done
export BOOT_CFLAGS="${BOOT_CFLAGS:-$CXXFLAGS}"

# stage1
filter-flags '-flto*' '*-lto-*'
#gcc_do_filter_flags || die
replace-flags '-O*' -O1
for i in $ff; do
	[[ " $(all-flag-vars) " == *" $i"* ]] || export ${i}="$CFLAGS"
	export ${i}_FOR_BUILD="${!i} -fno-lto"
	for j in 1; do
		export STAGE${j}_${i}="${!i} -fno-lto"
	done
done

[ -n "$NM" -a -z "$NM_FOR_TARGET" ] && export NM_FOR_TARGET="$NM"
[ -n "$AR" -a -z "$AR_FOR_TARGET" ] && export AR_FOR_TARGET="$AR"
[ -n "$RANLIB" -a -z "$RANLIB_FOR_TARGET" ] && export RANLIB_FOR_TARGET="$RANLIB"


#BOOT_CFLAGS=
ff=$(echo {CXX,LD,F,FC,GOC,LIBC,T,C}FLAGS)
ff0=" $(all-flag-vars) "

f=x
for i in $CFLAGS; do
	[[ "$i" == -O* ]] && f="$i"
done
case "$f" in
# need testing
-Os)f=-O2;;
-Ofast)f=-O3;;
x)
	f=-O2
	append-flags $f
	append-ldflags $f
;;
esac
replace-flags '-O*' $f
[ -e "$S/config/bootstrap$f.mk" ] && with_build_config+=" bootstrap$f" # ignored?

# static libs
f1=
# other
f2=
(is-flagq -flto || is-flagq '-flto=*') && {
	f1+=' -flto=jobserver'
	is-flagq -fuse-linker-plugin && with_build_config+=' bootstrap-lto' && f1+=' -fuse-linker-plugin' || with_build_config+=' bootstrap-lto-noplugin'
	replace-flags '-flto=*' -flto=jobserver
	replace-flags -flto -flto=jobserver
	filter-flags -ffat-lto-objects
	f2+="$f1 -fno-fat-lto-objects"
	f1+=' -ffat-lto-objects'
	# bootstrap substitute own, but I still use -flto *FLAGS_FOR_TARGET
	# outside and IMHO before (for early static libs). set system gcc-*
	for i in AR NM RANLIB; do
		x="${i}_FOR_TARGET"
		export $x="${!x:-${!i:-gcc-${i,,}}}"
	done
}
[[ " $IUSE " == *' mpx '* ]] && use mpx && with_build_config+=' bootstrap-mpx'
[ -n with_build_config ] && export with_build_config="${with_build_config# }"
filter-flags -ffast-math

# can filter or not here: custom cflags or not
#gcc_do_filter_flags || die
for i in $ff; do
	[[ "$ff0" == *" $i "* ]] && [ -n "${!i}" ] || export $i="$CFLAGS"
	export ${i}_FOR_TARGET="${!i}$f1"
	export $i="${!i}$f2"
	export STAGE_$i="${!i}"
done
export BOOT_CFLAGS="${BOOT_CFLAGS:-$CXXFLAGS}"

# stage1
filter-flags '-flto*' '*-lto-*'
#gcc_do_filter_flags || die
replace-flags '-O*' -O1
for i in $ff; do
	[[ "$ff0" == *" $i "* ]] && [ -n "${!i}" ] || export $i="$CFLAGS"
	export ${i}_FOR_BUILD="${!i}"
	export STAGE1_$i="${!i}"
done


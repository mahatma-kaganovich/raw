unset p f l

# sort out annihilated flags
# becouse I can;
#           don't inspect every "flags soring" in builds;
#           looks not dangerous;
#           speedup parsing...
for i in {C,CXX,CPP,LD,F,FC,_}FLAGS; do
	d=' '
	for i1 in ${!i}; do
		d="${d// $i1 / }"
		fy="${i1%=*}"
		fn="$fy"
		fw="$fy=*"
		case "$fy" in
		-fuse-ld)
			case "$C" in
			LLVM|GNU)continue;;
			esac
			[ -z "$LD" ] && export LD="ld.${i1#*=}"
		;;
		-[fmW]no-*)fy="${fy:0:2}${fy:5}";fw="$fy=*";;
		-[fmW]*)fn="${fy:0:2}no-${fy:2}";;
#		-O*)fw="-O[^${i1:2:1}]*";;
#		*)false;;
		esac
		[ "$fn" = "$i1" ] || d="${d// $fn / }"
		[ "$fy" = "$i1" -o "$fy" = "$fn" ] || d="${d// $fy / }"
		[[ "$d" == *' '$fw* ]] && {
			d2=' '
			for i2 in $d; do
				[[ "$i2" != $fw ]] && d2+="$i2 "
			done
			d="$d2"
		}
		d+="$i1 "
	done
	d="${d% }"
	export $i="${d# }"
done

case "$C" in
LLVM)
	export CC=clang CXX=clang++ CPP=clang-cpp LD=ld.lld
#	export LDFLAGS="-fuse-ld=lld $LDFLAGS"
	f='-fuse-ld=lld'
	p=llvm
#	l=thin
;;
GNU)
	export CC=gcc CXX=g++ CPP='gcc -E' LD=ld.bfd
	f='-fuse-ld=bfd'
	p=gcc
;;
X)
	export CC=cc CXX=c++ CPP=cpp LD=ld
	p=
;;
esac

! ([[ " $IUSE " == *' clang '* ]] && use clang) && [ -z "${CC#gcc}" ] && l=$ncpu
[ -v l ] && for i in {C,CXX,CPP,LD,F,FC,_}FLAGS; do
	export $i="${!i//-flto -fuse-linker-plugin/-flto=$l -fuse-linker-plugin}"
done
d="${TMPDIR}/bin"
for i in ar strip nm ranlib objcopy objdump   strings size readelf dwp; do
	i1=${i^^}
	[ -v p ] && i2=${p}-${i} && which $i2 && export $i1=$i2 HOST_$i1=$i2 ${i1}_FOR_TARGET=$i2 ${i1}_FOR_BUILD=$i2
	[ "${!i1:-$i}" = $i ] && continue
	mkdir -p "$d"
	echo "#/bin/sh
exec ${!i1} \"\${@}\"" >"$d/$i"
	chmod 770 "$d/$i"
	eval "$i(){
		${!i1} \"\${@}\"
	}"
	export -f $i
done >/dev/null 2>&1
[ -e "$d" -a -n "${PATH##$d:*}" ] && export PATH="$d:$PATH"
for i in  {,HOST_}{C,CXX,CPP,LD,F,FC,_}FLAGS; do
	[[ -v "$i" ]] || continue
	[[ -v f ]] && export $i="$f ${!i}"
	case " ${!i} " in
	*\ -flto[\ =]*)export $i="${!i// -Wa,--reduce-memory-overheads}";; # warnings
	esac
done
[ -v p ] && for i in CC CXX CPP LD; do
	export HOST_$i="${!i}"
done
unset p f l i i1 i2 i3 i4 d f2 f3 d2 fy fn fw

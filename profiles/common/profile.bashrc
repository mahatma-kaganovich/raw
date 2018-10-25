unset p f l
case "$C" in
LLVM)
	export CC=clang CXX=clang++ CPP=clang-cpp LD=ld.gold
	export LDFLAGS="$LDFLAGS -fuse-ld=gold"
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
[ -z "${CC#gcc}" ] && l=$ncpu
[ -v l ] && for i in {C,CXX,CPP,LD,F,FC,_}FLAGS; do
	export $i="${!i// -flto -fuse-linker-plugin / -flto=$l -fuse-linker-plugin }"
done
for i in ar strip nm ranlib objcopy objdump   strings size readelf dwp; do
	i1=${i^^}
	[ -v p ] && i2=${p}-${i} && which $i2 && export $i1=$i2 HOST_$i1=$i2
	[ "${!i1:-$i}" = $i ] && continue
	eval "$i(){
		${!i1} \"\${@}\"
	}"
	export -f $i
done >/dev/null 2>&1
[ -v f ] && for i in  {C,CXX,CPP,LD,F,FC,_}FLAGS; do
	export $i="${!i} $f"
	i="HOST_$i"
	[ -v $i ] && export $i="${!i} $f"
done
[ -v p ] && for i in CC CXX CPP LD; do
	export HOST_$i="${!i}"
done
unset p f l i

unset p f
case "$C" in
LLVM)
	export CC=clang CXX=clang++ CPP=clang-cpp LD=ld.gold
	export LDFLAGS="$LDFLAGS -fuse-ld=gold"
	p=llvm
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
[ -z "${CC#gcc}" ] && for i in {C,CXX,CPP,LD,F,FC,_}FLAGS; do
	export $i="${!i// -flto -fuse-linker-plugin / -flto=$ncpu -fuse-linker-plugin }"
done
[ -v p ] && for i in ar strip nm ranlib objcopy objdump   strings size readelf dwp; do
	which ${p}-${i} && export ${i^^}=${p}-${i} # || unset ${i^^}
done >/dev/null 2>&1
[ -v f ] && for i in  {C,CXX,CPP,LD,F,FC,_}FLAGS; do
	    export $i="${!i} $f"
done
unset p f i

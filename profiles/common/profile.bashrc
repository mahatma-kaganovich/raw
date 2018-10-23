unset p f
case "$CC" in
LLVM)
	export CC=clang CXX=clang++ CPP='clang -E' LD=ld.gold
	f='-with-ld=gold'
	p=llvm
;;
GNU)
	export CC=gcc CXX=g++ CPP='gcc -E' LD=ld.bfd
	f='-with-ld=bfd'
	p=gcc
;;
X)
	export CC=cc CXX=c++ CPP=cpp LD=ld
	p=
;;
esac
[ -v p ] && for i in ar strip nm ranlib objcopy objdump; do
	which ${p}-${i} && export ${i^^}=${p}-${i} # || unset ${i^^}
done >/dev/null
[ -v f ] && for i in CFLAGS CXXFLAGS LDFLAGS FFLAGS FCFLAGS; do
	    export $i="${!i} $f"
done
unset p f i

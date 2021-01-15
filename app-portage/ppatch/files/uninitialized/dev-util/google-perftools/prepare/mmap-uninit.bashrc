sed -i -e 's:^\(#ifndef MAP_ANONYMOUS\)$:\
#if defined(__linux__) \&\& !defined(MAP_UNINITIALIZED)\
# include <asm-generic/mman-common.h>\
#endif\
#ifndef MAP_UNINITIALIZED\
# define MAP_UNINITIALIZED 0\
#endif\
\1:' \
-e 's:MAP_PRIVATE *| *MAP_ANONYMOUS\|MAP_ANONYMOUS *| *MAP_PRIVATE:MAP_PRIVATE|MAP_ANONYMOUS|MAP_UNINITIALIZED:' "$S"/src/{,*/}*.cc

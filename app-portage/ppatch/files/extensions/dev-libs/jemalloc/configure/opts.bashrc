
case "$PV" in
4.5*)export with_malloc_conf=purge:decay;;
5.2.1)
	# mozillas: c++ operators wrapper segfault
	export enable_cxx=no
	# still segfaults (with uninitialized? 2test?
#	patch -Np1 -i /usr/ppatch/dev-libs/jemalloc/cxx-free.patch -d "$S"
	# from git
#	patch -Np1 -i /usr/ppatch/dev-libs/jemalloc/cxx17.patch -d "$S"
;;
esac
export enable_fill=no
export enable_cache_oblivious=no
# < 5
use x86 && export enable_munmap=yes


# retain:false (ex enable_munmap=yes) bad on 64bit
[[ "$PV" == 4.5* ]] && export with_malloc_conf=purge:decay
export enable_fill=no
export enable_cache_oblivious=no
# 5 & mozillas: c++ operators wrapper segfault
export enable_cxx=no


use x86 && export enable_munmap=yes
[[ "$PV" == 4.5* ]] && export with_malloc_conf=purge:decay
export enable_fill=no
export enable_cache_oblivious=no
# 5 & mozillas: c++ operators wrapper segfault
export enable_cxx=no

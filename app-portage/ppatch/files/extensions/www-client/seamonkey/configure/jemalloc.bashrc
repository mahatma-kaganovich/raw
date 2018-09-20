sed -i -e 's:--enable-stats:--disable-stats:' $(find "$WORKDIR" -name '*configure' -type f) $(find "$WORKDIR" -name 'jemalloc.m4' -type f)
export enable_stats=no

sed -i -e 's:--enable-stats:--disable-stats:' $(find "$WORKDIR" -name '*configure') $(find "$WORKDIR" -name 'jemalloc.m4')
export enable_stats=no


# without this - at least failed qmake linking with LTO (in install phase - sic!) by ignoring LDFLAGS,
# so force & respect all flags early
export EXTRA_CFLAGS="$CFLAGS"
export EXTRA_CXXFLAGS="$CXXFLAGS"
export EXTRA_CPPFLAGS="$CFLAGS"
export EXTRA_LFLAGS="$LDFLAGS"

sed -i -e 's: -D_DEBUG: :g' "$S"/libclamav/c++/Makefile*
export MAKEOPTS="$MAKEOPTS DISABLE_ASSERTIONS=1"

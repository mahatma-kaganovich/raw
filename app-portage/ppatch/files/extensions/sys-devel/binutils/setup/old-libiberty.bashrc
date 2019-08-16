[[ " $CFLAGS $LDFLAGS " == *' -flto'[=\ ]* ]] && mv "/usr/$(get_libdir)/binutils/${CTARGET:-$CHOST}/${PV}/libiberty."{a,a__}
true

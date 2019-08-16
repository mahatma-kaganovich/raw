[[ " $CFLAGS $LDFLAGS " == *' -flto'[=\ ]* ]] && rm "/usr/$(get_libdir)/binutils/${CTARGET:-$CHOST}/${PV}/libiberty.a__"
true

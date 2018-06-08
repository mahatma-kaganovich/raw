[[ " $CFLAGS " == *' -fuse-linker-plugin '* && " $LDLAGS " != *' -fuse-linker-plugin '* ]] && export LDFLAGS="$LDFLAGS $CFLAGS"
true

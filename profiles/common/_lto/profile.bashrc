[[ " $CFLAGS " == *' -fuse-linker-plugin '* && " $LDLAGS " != *' -fuse-linker-plugin '* ]] && export LDFLAGS="$LDFLAGS $CXXFLAGS"
true

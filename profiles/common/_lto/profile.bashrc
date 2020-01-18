#[[ " $CFLAGS " == *' -fuse-linker-plugin '* && " $LDFLAGS " != *' -fuse-linker-plugin '* ]] && export LDFLAGS="$LDFLAGS $CXXFLAGS"
[[ " $CFLAGS " == *\ -flto[=\ ]* && " $LDFLAGS " != *\ -flto[=\ ]* ]] && export LDFLAGS="$LDFLAGS $CXXFLAGS"
true

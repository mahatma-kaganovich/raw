
# use global LTO if exists
[[ " $CFLAGS " == *' -flto'* ]] && export with_lto=no || export with_lto=yes


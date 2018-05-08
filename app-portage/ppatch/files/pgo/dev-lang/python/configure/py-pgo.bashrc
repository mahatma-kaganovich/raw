case "$PV" in
2.7.*) # 3.4 absent, 3.5+ [sometimes] ICO
    [[ " $CFLAGS " != *' -flto '* ]] && {
	with_lto=no
	export enable_optimizations=yes
	export MAKEOPTS=-j1
    }
;;
esac

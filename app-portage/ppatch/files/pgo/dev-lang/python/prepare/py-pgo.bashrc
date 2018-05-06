case "$PV" in
2.7.*|3.5.*) # 3.4 absent, 3.5+ [sometimes] ICO
	# use system-wide LTO
	[[ " $CFLAGS " == *' -flto '* ]] && export with_lto=no
	export enable_optimizations=yes
	export MAKEOPTS=-j1
;;
esac

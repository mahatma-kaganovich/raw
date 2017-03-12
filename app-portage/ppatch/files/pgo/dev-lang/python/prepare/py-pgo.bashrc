case "$SLOT" in
2.7) # 3.4 absent, 3.5 & 3.6 internal compiler error
	# use system-wide LTO
	export with_lto=no
	export enable_optimizations=yes
	export MAKEOPTS=-j1
;;
esac

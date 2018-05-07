case "$PV" in
2.7.*) # 3.4 absent, 3.5+ [sometimes] ICO
	export enable_optimizations=yes
	export MAKEOPTS=-j1
;;
esac

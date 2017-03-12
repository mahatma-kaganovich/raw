case "$SLOT" in
2.7|3.4|3.5)
	# use system-wide LTO
	sed -i -e "s:Py_LTO='true':Py_LTO='false':" "$S"/configure*
	export enable_optimizations=yes
	export MAKEOPTS=-j1
;;
esac

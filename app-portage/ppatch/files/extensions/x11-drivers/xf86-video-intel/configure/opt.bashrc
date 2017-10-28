[[ " $IUSE " != *' sna '* ]] || use !sna || {
#	export enable_tear_free=yes
	export enable_create2=yes
	# dri2
	export enable_async_swap=yes
}
if [[ " $IUSE " == *' uxa '* ]] && use uxa; then
	export enable_dga=yes
	export enable_xaa=yes
else
	export enable_dga=no
	export enable_xaa=no
fi

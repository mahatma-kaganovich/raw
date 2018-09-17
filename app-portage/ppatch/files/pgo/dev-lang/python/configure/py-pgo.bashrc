case "$PV" in
2.7.*) # 3.4 absent, 3.5+ [sometimes] ICO
    [[ " $CFLAGS " != *' -flto'* ]] && {
	export with_lto=no
	export enable_optimizations=yes
	export MAKEOPTS=-j1
	unlink "$S"/Lib/distutils/tests/test_bdist_rpm.py
    }
;;
3.[45].*);;
*)
	export enable_optimizations=yes
	export MAKEOPTS=-j1
	rm "$S"/Lib/distutils/tests/test_bdist_rpm.py "$S"/Lib/test/test_compileall.py
	rm "$S"/Lib/test/test_socket.py
;;
esac

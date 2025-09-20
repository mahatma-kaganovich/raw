case "$PN" in
#ftgl||liboil|monoghc|emacs*
nss|mypaint|pidgin|gtk+|binutils|kmscon)
	replace-flags(){ true;}
	export -f replace-flags
	strip-flags(){ true;}
	export -f strip-flags
;;
esac


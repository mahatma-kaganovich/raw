case "$PN" in
#nss|ftgl|mypaint|liboil|monoghc|emacs*
pidgin|gtk+|binutils|kmscon)
	replace-flags(){ true;}
	export -f replace-flags
	strip-flags(){ true;}
	export -f strip-flags
;;
esac


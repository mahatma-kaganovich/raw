## Upgrade "new" -> "current" config (/etc):
## - If md5sum of current not changed - replacing by new.
## - If exists "current.patch" & "original" reverse diff md5sum is not changed -
## make diff of new & original and applying to current.
## - If new md5sum is alredy installed - writing "current.diff" & removing new.
##
## decorations are dangerous ;)
##
## /var/db/pkg/*/*/CONTENTS md5 are strange and may be incorrect,
## using own /var/cache/conf.bashrc/...

iscurrent(){
	local m=`md5sum "$1"`
	grep -qsF " ${m%% *} ${i1r} " "$mf"
	return $?
}

upcf(){
	local i i1 i1r d c=" [conf]" p="$ROOT/var/cache/conf.ppatch/$CATEGORY/$PN/$SLOT"
	local mf="$p/md5" m
	mkdir -p "$p"
	echo -n "" >"$mf.merge" || return 1
	find "${D}"/etc -print|while read i; do
		i1r="${i#$D}"
		i1="${ROOT}${i1r}"
		[[ -f "$i1" ]] && m=`md5sum "$i"` || continue
		echo " ${m%% *} $i1r " >>"$mf.merge"
		cmp -s "$i1" "$i" && continue
		if iscurrent "$i1"; then
			if head -n1 "$i"|grep -q "^# empty"; then
				echo "$c Empty: $i"
			else
				echo "$c Replacing: $i1"
				echo "cp $i $i1 -a"
				cp "$i" "$i1" -a
			fi
			continue
		fi
		d="${i1%/*}"
		if [[ -e "$i1.patch" ]]; then
			if patch -stNd "${i%/*}" -i "$i1.patch" -o - -r - | cmp -s - "$i1" ||
			    ( echo "$c Upgrading: $i1"; patch -sRtNd "$d" -i "$i1.patch" -o - -r - ${ETC_PATCH} | iscurrent - &&
			    ( patch -sRtNd "$d" -i "$i1.patch" -o - -r - ${ETC_PATCH} |diff -pruN - "$i" ${ETC_DIFF} |patch -stNd "$d" ${ETC_PATCH} ) ); then
				echo "$i" >>"$p/rm.tmp"
				continue
			fi
			echo "$c Upgrading failed"
		fi
#		if iscurrent "$i"; then
			echo "$c diff: $i1.diff"
			diff -pruN "$i" "$i1" ${ETC_DIFF} >"$i1.diff"
			echo "$i" >>"$p/rm.tmp"
#		fi
	done
	mv "$mf.merge" "$mf"
}

rmcf(){
	local i i1 t="$ROOT/var/cache/conf.ppatch/$CATEGORY/$PN/$SLOT/rm.tmp"
	[[ -e "$t" ]] && cat "$t"|while read i; do
		i1="${ROOT}${i#$D}"
		for i1 in "${i1%/*}"/._cfg????_"${i1##*/}"; do
			cmp -s "$i" "$i1" && rm "$i1"
		done
	done
}

[[ -e "${D}/etc" ]] && case "$EBUILD_PHASE" in
preinst)upcf;;
postinst)rmcf;;
esac

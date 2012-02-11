## Upgrade "new" -> "current" config (/etc):
## - If md5sum of current not changed - replacing by new.
## - If exists "current.patch" or ".current.patch"  & "original" reverse diff md5sum is not
## changed - make diff of new & original and applying to current.
## - If new md5sum is alredy installed - writing ".current.DIFF", if no - ".current.diff"
## & removing new.
## - Usually ".current.DIFF" ready to be renamed to ".current.patch".
##
## decorations are dangerous ;)
##
## /var/db/pkg/*/*/CONTENTS md5 are strange and may be incorrect,
## using own /var/cache/conf.bashrc/...

conf_bashrc(){
[[ -e "${D}/etc" ]] || return
local p="$ROOT/var/cache/conf.ppatch/$CATEGORY/$PN/$SLOT"
local mf="$p/md5" t="$p/rm.tmp"
case "$EBUILD_PHASE" in
preinst)
	local i i1 i1r d c=" [conf]" m s
	mkdir -p "$p"
	rm "$t" -f
	echo -n "" >"$mf.merge" || return 1
	find "${D}"/etc -print|while read i; do
		i1r="${i#$D}"
		i1="${ROOT}${i1r}"
		[[ -f "$i1" ]] && m=`md5sum "$i"` || continue
		echo " ${m%% *} $i1r " >>"$mf.merge"
		cmp -s "$i1" "$i" && continue
		m=`md5sum "$i1"` || continue
		if grep -qsF " ${m%% *} ${i1r} " "$mf"; then
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
		s="$i1.patch"
		if ( [[ -e ".$s" ]] && s=".$s" ) || [[ -e "$s"  ]]; then
			if patch -stNi "$s" "$i" -o - -r - |cmp -s - "$i1"; then
				echo "$c Already upgraded: $s"
				continue
			fi
			m=`patch -sRtNi "$i1.patch" "$i1" -o - -r - |md5sum -` || continue
			if grep -qsF " ${m%% *} ${i1r} " "$mf"; then
				if patch -sRtNi "$s" "$i1" -o - -r - | diff -pruN - "$i" | patch -stN "$i1"; then
					echo "$c Upgrading: $s"
					echo "$i" >>"$t"
					continue
				fi
				echo "$c Upgrading failed: $s"
			else
				echo "$c Upgrading failed: $s - original was changed outside the patch"
			fi
		fi
		m=`md5sum "$i"` || continue
		grep -qsF " ${m%% *} ${i1r} " "$mf" && s=DIFF || s=diff
		s="$d/.${i1##*/}.$s"
		echo "$c diff: $s"
		diff -pruN "$i" "$i1" >"$s"
		echo "$i" >>"$t"
	done
	mv "$mf.merge" "$mf"
;;
postinst)
	local i i1
	[[ -e "$t" ]] || return
	cat "$t"|while read i; do
		i1="${ROOT}${i#$D}"
		for i1 in "${i1%/*}"/._cfg????_"${i1##*/}"; do
			cmp -s "$i" "$i1" && rm "$i1"
		done
	done
	rm "$t" -f
;;
esac
}

conf_bashrc

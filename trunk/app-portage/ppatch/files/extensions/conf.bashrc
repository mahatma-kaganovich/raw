## Upgrade "new" -> "current" config (/etc):
## - If md5sum of current not changed - replacing by new.
## - If exists "current.patch" & "original" reverse diff md5sum is not changed -
## make diff of new & original and applying to current.
## - If new md5sum is alredy installed - writing "current.diff" & removing new.
##
## decorations are dangerous ;)

iscurrent(){
	local m=`md5sum "$1"`
	grep -sq "^obj ${2:-1} ${m%% *} " /var/db/pkg/$CATEGORY/$PN*/CONTENTS
	return $?
}

upcf(){
	local i i1 m dif d c=" [conf]"
	find "${D}"/etc -print|while read i; do
		i1="${i#$D}"
		[[ -f "$i1" ]] || continue
		cmp -s "$i1" "$i" && continue
		if iscurrent "$i1"; then
			echo "$c Replacing: $i1"
			cp "$i" "$i1" -a
			continue
		fi
		d="${i1%/*}"
		if [[ -e "$i1.patch" ]] && ( patch -sRtNd "$d" -i "$i1.patch" -o - -r - | iscurrent - "$i1" ); then
			echo "$c Upgrading: $i1"
			patch -sRtNd "$d" -i "$i1.patch" -o - -r - |diff -pruN - "$i"|patch -stNd "$d" && {
				rm "$i"
				continue
			}
			echo "$c Upgrading failed"
		fi
		if iscurrent "$i" "$i1"; then
			echo "$c diff: $i1.diff"
			diff -pruN "$i" "$i1" >"$i1.diff"
			rm "$i"
		fi
	done
}

[[ "$EBUILD_PHASE" == preinst ]] && [[ -e "${D}/etc" ]] && upcf

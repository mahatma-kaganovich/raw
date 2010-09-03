## Upgrade "new" -> "current" config (/etc):
## - If md5sum of current not changed - replacing by new.
## - If exists "current.patch" & "original" reverse diff md5sum is not changed -
## make diff of new & original and applying to current.
## - If new md5sum is alredy installed - writing "current.diff" & removing new.
##
## decorations are dangerous ;)

iscurrent(){
	local m=`md5sum "$1"`
	grep -sq "^obj ${i1r} ${m%% *} " "${ROOT}"/var/db/pkg/$CATEGORY/$PN*/CONTENTS
	return $?
}

upcf(){
	local i i1 i1r d c=" [conf]"
	find "${D}"/etc -print|while read i; do
		i1r="${i#$D}"
		i1="${ROOT}${i1r}"
		[[ -f "$i1" ]] || continue
		cmp -s "$i1" "$i" && continue
		if iscurrent "$i1"; then
			echo "$c Replacing: $i1"
			cp "$i" "$i1" -a
			continue
		fi
		d="${i1%/*}"
		if [[ -e "$i1.patch" ]]; then
			if patch -stNd "${i%/*}" -i "$i1.patch" -o - -r - | cmp -s - "$i1" ||
			    ( echo "$c Upgrading: $i1"; patch -sRtNd "$d" -i "$i1.patch" -o - -r - ${ETC_PATCH} | iscurrent - &&
			    ( patch -sRtNd "$d" -i "$i1.patch" -o - -r - ${ETC_PATCH} |diff -pruN - "$i" ${ETC_DIFF} |patch -stNd "$d" ${ETC_PATCH} ) ); then
				echo "$i" >>"${TMPDIR}"/conf.bashrc.rm.tmp
				continue
			fi
			echo "$c Upgrading failed"
		fi
		if iscurrent "$i"; then
			echo "$c diff: $i1.diff"
			diff -pruN "$i" "$i1" ${ETC_DIFF} >"$i1.diff"
			echo "$i" >>"${TMPDIR}"/conf.bashrc.rm.tmp
		fi
	done
}

rmcf(){
	local i i1
	cat "${TMPDIR}"/conf.bashrc.rm.tmp|while read i; do
		i1="${ROOT}${i#$D}"
		for i1 in "${i1%/*}"/._cfg????_"${i1##*/}"; do
			cmp -s "$i" "$i1" && rm "$i1"
		done
	done
}

[[ -e "${D}/etc" ]] && case "$EBUILD_PHASE" in
preinst)upcf;;
postinst)[[ -e "${TMPDIR}"/conf.bashrc.rm.tmp ]] && rmcf;;
esac

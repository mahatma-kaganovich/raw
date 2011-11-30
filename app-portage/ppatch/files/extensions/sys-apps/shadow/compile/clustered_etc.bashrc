# shadow (or pam or shadow[pam]) use hardcoded /etc/* file names.
# in some cases (drbd cluster, etc) useful symlinks for this files,
# but symlinks works unless you change something.
# change name constants to current symlinks targets to workaround.
# pass1: move passwd|shadow|etc, symlink,
# then "emerge -1 sys-apps/shadow sys-libs/pam"
for i in passwd shadow group gshadow security/opasswd; do
	[[ -L "/etc/$i" ]] || continue
	l=`readlink -f /etc/$i` || continue
	[[ -z "$l" ]] && continue
	# shadow
	[[ -e "$S/lib/defines.h" ]] && sed -i -e "s:\"/etc/$i\":\"$l\":" "$S/lib/defines.h" && continue
	# pam
	sed -i -e "s:\"/etc/$i\":\"$l\":" -e "s:\"/etc/n$i\":\"${l%/*}/n${i##*/}\":" "$S/modules/pam_unix/"*
done

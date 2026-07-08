# shadow (or pam or shadow[pam]) use hardcoded /etc/* file names.
# in some cases (drbd cluster, etc) useful symlinks for this files,
# but symlinks works unless you change something.
# change name constants to current symlinks targets to workaround.
# pass1: move passwd|shadow|etc, symlink,
# then "emerge -1 sys-apps/shadow sys-libs/pam"
[ -e "$S"/lib/defines.h ] && ! [ -e "$S"/lib/paths.h ] && cp -a /usr/include/paths.h "$S"/lib/
for i in passwd shadow group gshadow security/opasswd; do
	[[ -L "/etc/$i" ]] || continue
	l=`readlink -f /etc/$i` || continue
	[[ -z "$l" ]] && continue
	# shadow
	[ -e "$S/lib/defines.h" ] &&
	    sed -i -e "s:\"/etc/$i\":\"$l\":" "$S"/lib/{defines,paths}.h && continue
	# pam
	sed -i -e "s:\"/etc/$i\":\"$l\":" -e "s:\"/etc/n$i\":\"${l%/*}/n${i##*/}\":" "$S/modules/pam_unix/"*
done

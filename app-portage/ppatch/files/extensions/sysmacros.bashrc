[ "$EBUILD_PHASE" = configure ] && case "$PN" in
xorg-server|lxc|seamonkey|weston|libreoffice|ceph|mongodb|spacefm|nfs-utils|ocfs2-tools)
	for i in sys/types libudev; do
		sed -i -e "s:^#include <$i\\.h>:#include <sys/sysmacros.h>\n#include <$i.h>:" `grep -lR "^#include <$i\\.h>" "$S"`
	done
;;
esac

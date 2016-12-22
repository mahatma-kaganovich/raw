[ "$EBUILD_PHASE" = prepare ] && case "$PN" in
xorg-server|lxc|gvfs|seamonkey|weston|libreoffice|ceph|mongodb|spacefm|nfs-utils)
	for i in sys/types libudev; do
		sed -i -e "s:^#include <$i\\.h>:#include <sys/sysmacros.h>\n#include <$i.h>:" `grep -lR "^#include <$i\\.h>" "$S"`
	done
;;
esac
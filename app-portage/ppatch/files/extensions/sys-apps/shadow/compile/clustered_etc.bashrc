for i in passwd shadow group gshadow; do
	[[ -L "/etc/$i" ]] || continue
	l=`readlink -f /etc/$i` || continue
	[[ -z "$l" ]] && continue
	sed -i -e "s:\"/etc/$i\":\"$l\":" "$S/lib/defines.h"
done

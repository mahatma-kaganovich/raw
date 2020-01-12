

rights(){
	[ "`stat "$D$1" --printf='%a.%u.%g' 2>/dev/null`" = "$2.0.0" -a "`stat $1 --printf='%a.%u.%G' 2>/dev/null`" = "$3.0.$4" ] &&
		chgrp $4 "$D$1" && chmod $3 "$D$1"
}
rights2(){
	rights $1 755 4754 $2 ||
	rights $1 755 4710 $2
}

rights /usr/sbin/pppd 4555 4510 uucp
rights /usr/sbin/pppd 4555 511 root
for i in /sbin/openrc-shutdown /sbin/halt; do
	[ -e "$D/$i" ] || continue
	rights2 $i plugdev
	break
done
rights2 /usr/bin/rfcomm uucp

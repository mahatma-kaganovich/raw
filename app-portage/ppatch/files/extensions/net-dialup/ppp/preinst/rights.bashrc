

rights(){
	[ "`stat "$D$1" --printf='%a.%u.%g' 2>/dev/null`" = "$2.0.0" -a "`stat $1 --printf='%a.%u.%G' 2>/dev/null`" = "$3.0.$4" ] &&
		chgrp $4 "$D$1" && chmod $3 "$D$1"
}

rights /usr/sbin/pppd 4555 4510 uucp
rights /usr/sbin/pppd 4555 511 root
rights /sbin/halt 755 4754 plugdev
rights /sbin/halt 755 4710 plugdev
rights /usr/bin/rfcomm 755 4754 uucp
rights /usr/bin/rfcomm 755 4710 uucp

#!/bin/sh

cd /lib/modules/${KV:=`uname -r`}
modparam(){ return;}
. /etc/modparam.sh
. ./modules.alias.sh

_modprobe(){
local m="$(echo -ne "$1" | sed -e s/-/_/g)" i
shift
for m in $m; do
	modalias "$m" && for i in $ALIAS ; do
		modparam $i
		$INSMOD
		insmod $i $PARAM "${@}"
		r=$?
	done
done
}

modprobe(){
local r=1 INSMOD=""
while true; do
case "$1" in
-a|--all)
	shift
	_modprobe "$*"
	return $r
;;
-*);;
*)break;;
esac
shift
done
_modprobe "${@}"
return $r
}

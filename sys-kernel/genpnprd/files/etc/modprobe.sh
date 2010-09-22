#!/bin/sh

cd /lib/modules/${KV:=`uname -r`}
modparam(){ return;}
. /etc/modparam.sh
. ./modules.alias.sh

modprobe(){
local r=1 INSMOD="" a=false
while true; do
case "$1" in
--)shift;break;;
-*a*)a=true;;
-*);;
*)break;;
esac
shift
done
$a && set "$*"
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
return $r
}

case $0 in
*modprobe*)modprobe "${@}";exit $?;;
esac

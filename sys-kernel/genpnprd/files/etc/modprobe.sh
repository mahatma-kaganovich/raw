#!/bin/sh

modalias(){ ALIAS=`find -name "$1.ko"`;return $?;}
cd /lib/modules/${KV:=`uname -r`}
[[ -e ./modules.alias.sh ]] && . ./modules.alias.sh # || return 1
modparam(){ return;}
[[ -e /etc/modparam.sh ]] && . /etc/modparam.sh

modverbose(){
	echo "insmod $i $PARAM" >&2
}

modprobe(){
local rr=0 r=1 INSMOD="" a=false V=
while true; do
case "$1" in
--)shift;break;;
-*a*)a=true;;
-*v*)V=modverbose;;
-*);;
*)break;;
esac
shift
done
$a && set "$*"
local m="$(echo -ne "$1" | sed -e s/-/_/g)" i
shift
for m in $m; do
	a="/temp/cache/modprobe/$m.m"
	[[ -e "$a" ]] && continue
	r=0
	modalias "$m" && for i in $ALIAS ; do
		modparam $i
		$INSMOD
		insmod $i $PARAM "${@}" || { r=1;continue;}
		$V
	done || rr=1
	if [[ $r == 0 ]]; then
		touch "$a" 2>/dev/null
	else
		rr=1
	fi
done
return $r$rr
}

case $0 in
*modprobe*)modprobe "${@}";exit $?;;
esac

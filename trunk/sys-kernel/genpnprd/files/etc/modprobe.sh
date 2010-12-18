#!/bin/sh

modalias(){ ALIAS=`find -name "$1.ko"`;return $?;}
cd /lib/modules/${KV:=`uname -r`}
[[ -e ./modules.alias.sh ]] && . ./modules.alias.sh # || return 1
modparam(){
	PARAM="${1##*/}"
	PARAM="`cat "/etc/kernel.cmdline/${PARAM%.ko}".* 2>/dev/null`"
}
[[ -e /etc/modparam.sh ]] && . /etc/modparam.sh

modverbose(){
	echo "insmod $i $PARAM" >&2
}

modprobe(){
local i m m1 rr=0 r=1 INSMOD= a=false V= c=/temp/cache/modprobe/
while true; do
case "$1" in
--)shift;break;;
-*)	i="$1"
	while [[ -n "$i" ]]; do
		i="${i#?}"
		case "$i" in
		a*)a=true;;
		v*)V=modverbose;;
		esac
	done
;;
*)break;;
esac
shift
done
$a && set "$*"
m="$(echo -ne "$1" | sed -e s/[*?/-]/_/g)"
shift
[[ "$a${_cmd_fastboot}" == true_ ]] && {
	r=0
	for m in $m; do
	[[ -e "$c$m.m" ]] || {
		modalias "$m" && for i in $ALIAS ; do
			modparam $i
			$INSMOD
			insmod $i $PARAM || { r=1;continue;}
			$V
		done
		[[ $r == 0 ]] && touch "$c$m.m" 2>/dev/null
	} &
	p="$p $!"
	{ read i m i && read i m1 i;} </proc/meminfo && {
		let i=m/m1
		[[ $i -lt 2 ]] && continue
	}
	wait $p
	p=
	done
	wait $p
	return $?
}
for m in $m; do
	[[ -e "$c$m.m" ]] && continue
	r=0
	modalias "$m" && for i in $ALIAS ; do
		modparam $i
		$INSMOD
		insmod $i $PARAM "${@}" || { r=1;continue;}
		$V
	done || rr=1
	if [[ $r == 0 ]]; then
		touch "$c$m.m" 2>/dev/null
	else
		rr=1
	fi
done
return $r$rr
}

case $0 in
*modprobe*)modprobe "${@}";exit $?;;
esac

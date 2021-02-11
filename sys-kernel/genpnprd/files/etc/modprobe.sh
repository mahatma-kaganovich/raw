#!/bin/sh

modalias(){ ALIAS=`find -name "$1.ko"`;return $?;}
[ -n "$KV" ] || read KV </proc/sys/kernel/osrelease || KV=`uname -r||ls /lib/modules`
cd /lib/modules/$KV
[ -e ./modules.alias.sh ] && . ./modules.alias.sh # || return 1
modparam(){
	PARAM="${1##*/}"
	PARAM="`cat "/etc/kernel.cmdline/${PARAM%.ko}".* 2>/dev/null`"
}
[ -e /etc/modparam.sh ] && . /etc/modparam.sh

modverbose(){
	echo "insmod $i $PARAM" >&2
}

modprobe(){
local i m m1 rr=0 r=1 INSMOD= a=false V= c=/cache.modprobe/
[ -w $c ] || c=/sys/module/
while true; do
case "$1" in
--)shift;break;;
-*)	i="$1"
	while [ -n "$i" ]; do
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
m="$1"
[ -n "$m" ] && while [ -z "${m##*[*?/-]*}" ]; do
	m="${m%%[*?/-]*}_${m#*[*?/-]}"
done
shift
[ "$a${_cmd_fastboot}" = true_ ] && {
	r=0
	for m in $m; do
	[ -e "$c$m" ] || {
		modalias "$m" && for i in $ALIAS ; do
			[ -e "$c$i" ] && continue
			modparam $i
			$INSMOD
			insmod $i $PARAM || { r=1;continue;}
			mkdir -p "$c$i" 2>/dev/null
			$V
		done
		[ $r -eq 0 ] && touch "$c$m" 2>/dev/null
	} &
	p="$p $!"
	{ read i m i && read i m1 i;} </proc/meminfo && [ $((m/m1)) -lt 2 ] && continue
	wait $p
	p=
	done
	wait $p
	return $?
}
for m in $m; do
	[ -e "$c$m" ] && continue
	r=0
	modalias "$m" && for i in $ALIAS ; do
		[ -e "$c$i" ] && continue
		modparam $i
		$INSMOD
		insmod $i $PARAM "${@}" || { r=1;continue;}
		mkdir -p "$c$i" 2>/dev/null
		$V
	done || rr=1
	if [ $r -eq 0 ]; then
		touch "$c$m" 2>/dev/null
	else
		rr=1
	fi
done
return $r$rr
}

case $0 in
*modprobe*)modprobe "${@}";exit $?;;
esac

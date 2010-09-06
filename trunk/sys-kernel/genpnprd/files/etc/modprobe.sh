#!/bin/sh

cd /lib/modules/${KV:=`uname -r`}
. /etc/modparam.sh
. ./modules.alias.sh

modprobe(){
while [[ "${1#-}" != "$1" ]] ; do
	shift
done
m="$1"
shift
modalias "$(echo -ne "$m" | sed -e s/-/_/g)" && for i in $ALIAS ; do
	modparam $i
	wait $pid
	pid=""
	$insmod $i $PARAM "${@}" &
	pid="$!"
done
${modprobe_wait:-wait} $pid
return $?
}

#export -f modalias modparam modprobe

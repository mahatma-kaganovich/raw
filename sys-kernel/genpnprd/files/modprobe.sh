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
r=1
modalias "$(echo -ne "$m" | sed -e s/-/_/g)" && for i in $ALIAS ; do
	modparam $i
	$insmod $i $PARAM $*
	r=$?
done
return $r
}

#export -f modalias modparam modprobe

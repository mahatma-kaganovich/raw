#!/bin/bash
# (c) Denis Kaganovich, under Anarchy license
# tint2 execp for wifi monitor
# use iwmon (iwd) & ip (iproute2), but works with wpa_supplicant too
# re-used ya-nrg for sudo one-point

nrg='sudo -n -- /usr/sbin/ya-nrg'

nxt(){
unset ssid
unset t
unset mBm
unset freq
}

nxt
unset conn
unset src
unset src1
unset src2
unset dev
unset via
unset s1
connect=false
echo "    ?    
"
echo $'\x1b[2J-' >&2

show(){
local s
[ -v src ] && s=+ || s=_
if [ "$conn" = "$ssid" ]; then
	cfreq=$freq
	ct=$t
fi
s="${cfreq:-    }$s${ct:-   } 
$conn"
[ "$s" != "$s1" ] && s1="$s" && echo "$s"
s="$dev $src"
[ "$s" != "$src1" ] && src1="$s" && echo $'\x1b[2J'"${s:--}" >&2
}

subv(){
	i="${1#* $2 }"
	[ "$1" != "$i" ] && i="${i%% *}"
}

isw(){
	[ -e "/sys/class/net/$1/wireless" ]
}

{
ip ro
$nrg iwmon &
exec ip monitor
}| while read x; do
#	echo "	$x" >&2
	y="${x#*: }"
	case "$x" in
	'>'*)
#		echo "	$x" >&2
		$connect && conn="$ssid" && connect=false
		[ -v ssid -a "$ssid" = "$conn" ] && show
		nxt
	;;&
	'> Event: Disconnect'*)
		unset conn
		show
		$nrg wifi-sleep &
	;;
	'> Event: Connect '*)connect=true;; # no dhcp
	'Status: 1 (0x00000001)')conn="$ssid";show;; # dhcp
	'SSID: '*)ssid="$y";;
	WPA:|RSN:)t="${x%:}";;
	'Signal mBm: '*)y="000${y#-}";y="${y:(-4):2}";y="${y#0}";mBm="$y";;
	'Frequency: '*)freq="${y%% *}";;
	'> Complete: Get Scan '*)show;;
	'default via '*' dev '*)
		subv "$x" dev && isw "$i" || continue
		dev="$i"
		subv "$x" via
		via="$i"
		unset src
		[ "$dev" = "$dev2" ] && src="$src2"
		subv "$x" src && src="$i"
		show
	;;
	'local '*' dev '*)
		subv "$x" dev && isw "$i" || continue
		dev2="$i"
		subv " $x" local
		src2="$i"
	;;
	"Deleted local $src dev $dev "*)unset src;unset dev;unset via;show;;
	esac
done

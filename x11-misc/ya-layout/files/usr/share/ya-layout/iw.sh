#!/bin/bash
# (c) Denis Kaganovich, under Anarchy license
# tint2 execp for wifi monitor
# use iwmon (iwd) & ip (iproute2), but works with wpa_supplicant too
# re-used ya-nrg for sudo one-point

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
unset s1
scan=false
connect=false
echo "    ?    
"
echo $'\x1b[2J-' >&2

show(){
local r
[ -v src ] && r=+ || r=_
if [ "$conn" = "$ssid" ]; then
	cfreq=$freq
	ct=$t
fi
s="${cfreq:-    }$r${ct:-   } 
$conn"
[ "$s" != "$s1" ] && s1="$s" && echo "$s"
[ "$src" != "$src1" ] && src1="$src" && echo $'\x1b[2J'"${src:--}" >&2
}

{
ip ro
sudo -n /usr/sbin/ya-nrg iwmon & ip monitor
}| while read x; do
#	echo "	$x" >&2
	y="${x#*: }"
	v="${x%%:*}"
	set - $y
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
	;;
	'> Event: Connect '*)connect=true;;
	'Status: 1 (0x00000001)')conn="$ssid";show;;
	'SSID: '*)ssid="$y";;
	WPA:|RSN:)t="$v";;
	'Signal mBm: '*)y="000${y#-}";y="${y:(-4):2}";y="${y#0}";mBm="$y";;
	'Frequency: '*)freq=$1;;
	'> Complete: Get Scan '*)show;;
	'default via '*' src '*)
		src="${x##* src }"
		src="${src%% *}"
		show
	;;
	"Deleted local $src "*)unset src;show;;
	esac
done

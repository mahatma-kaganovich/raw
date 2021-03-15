#!/bin/bash
# (c) Denis Kaganovich, under Anarchy license
# tint2 execp for wifi monitor
# use iwmon (iwd) & ip (iproute2), but works with wpa_supplicant too
# re-used ya-nrg for sudo one-point

nrg='sudo -n -- /usr/sbin/ya-nrg'

# 'ip monitor' may be replaced by 'ipmon' without '-n'
# but routes add errors are dirty
ipmon=false

# next connect
nxt(){
unset ssid t mBm freq "${@}"
}

# next preconnect state
nxt1(){
	preconnect=${1:-false}
	preconnect2=${2:-$preconnect}
	${3:-$preconnect2} || nxt freq1 t1 ssid1
	$preconnect || $preconnect2 || {
		nxt conn cfreq ct
		[ -v ssid1 ] && conn=$ssid1
		show
	}
}

unset src src1 src2 src3 dev dev2 dev3 via s1
connect=false
nxt1
echo "    ?    
"
echo $'\x1b[2J-' >&2


_subv(){
	i="${1#$2}"
	[ "$1" != "$i" ] && i="${i%%$3*}"
}

subv(){
	_subv "$1" "* $2 " ' '
}

subv2(){
_subv "$1" "*
$2" '
' || _subv "$1" "$2" '
'
}

show(){
local s=_
[ -v src ] && s=+ && [ -z "$conn" ] && {
	local c=$(iwctl station "$dev" show|sed -e 's:  *: :g' -e 's: $::')
	subv2 "$c" ' Connected network ' && conn=$i &&
		[ -z "$cfreq" ] && subv2 "$c" ' Frequency ' && cfreq=$i
}
[ -v conn ] && if [ "$conn" = "$ssid" ]; then
	cfreq=${freq:-$freq1}
	ct=${t1:-$t}
elif [ "$conn" = "$ssid1" ]; then
	cfreq=$freq1
	ct=$t1
fi
s="${cfreq:-    }$s${ct:-   } 
$conn"
[ "$s" != "$s1" ] && s1="$s" && echo "$s"
s="$dev $src"
[ "$s" != "$src1" ] && src1="$s" && echo $'\x1b[2J'"${s:--}" >&2
}

isw(){
	[ -e "/sys/class/net/$1/wireless" ]
}

adel(){
	unset src dev via src2
	show
}

{
echo 'ro list table local
ro'|ip -force -batch -
if $ipmon; then
	$nrg iwmon &
	exec ip monitor
else
	exec $nrg iwmon
fi
}| while read x; do
#	echo "	$x" >&2
	y="${x#*: }"
	case "$x" in
	'>'*)
		if $connect; then
			connect=false
			conn="${ssid:-$ssid1}"
			[ -v conn ] && show
		elif [ -v conn -a "${ssid:-$ssid1}" = "$conn" ]; then
			show
		fi
		nxt
	;;&
	[\<\>]*)
		[ -v RTNL ] && {
			! [ -v dev3 ] && [ -v ifindex ] && for i in /sys/class/net/*/ifindex; do
				[ "$(< $i)" = "$ifindex" ] && i=${i%/*} && dev3=${i##*/} && break
			done
			case "$RTNL:$x" in
			rnewA:'> RTNL: Error (0x02) len 20 [0x100]'*)RTNL=${RTNL%A};;
			esac
			[ -v dev3 ] && isw "$dev3" && case "$RTNL" in
			anew)[ -v src3 ] && src2=$src3 && dev2=$dev3;;
			rnew)[ "$dev2" = "$dev3" ] && src=$src2 && dev=$dev2 && show;;
			adel)[ "$dev" = "$dev3" -a "$src" = "$src3" ] && adel;;
			esac
		}
		unset RTNL src3 dev3 ifindex via
	;;&
	'> Event: Disconnect'*)nxt1;$nrg wifi-sleep;;
	'> Event: Connect '*)connect=true;; # no dhcp
	'Status: '*)
		case "$y" in
		'1 (0x00000001)'*)! $preconnect2 && conn="${ssid:-$ssid1}" && show;;& # dhcp?
		*)$preconnect2 || continue;;&
		Success\ *)nxt1 false false true;;
		*)nxt1;;
		esac
	;;
	'SSID: '*)ssid="$y";
		[[ "$ssid" == 'len '[0-9] ]] && {
			i=${ssid#len }
			i=${i%% *}
			i=$[0-i]
			[ "$i" != 0 ] && read ssid && ssid=${ssid:$i} || unset ssid
		}
		$preconnect && ssid1=$ssid
	;;
	WPA:*|RSN:*)t="${x%:}";;
	'Signal mBm: '*)y="000${y#-}";y="${y:(-4):2}";y="${y#0}";mBm="$y";;
	'Frequency: '*)freq="${y%% *}";;
	'WPA Versions: '*)$preconnect && t1="WPA${y%% *}";;
	'Wiphy Frequency: '*)$preconnect && freq1="${y%% *}";;
	'> Complete: Get Scan '*)show;;
	'< Request: Connect '*)nxt1 true false;;
	'> Response: Connect '*)nxt1 $preconnect;;
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
	"Deleted local $src dev $dev "*)adel;;
	'> RTNL: New Address '*)RTNL=anew;;
	'> RTNL: Delete Address '*)RTNL=adel;;
	'> RTNL: New Route '*)RTNL=rnew;;
	'< RTNL: New Route '*)RTNL=rnewA;;
	'Interface Address: '*)src3=$y;;
	'Gateway: '*)via=$y;;
	'Label (len:6): '*|'Interface Name: '*)dev3=$y;;
	'Output Interface Index: '*)ifindex=${y%% *};;
	esac
done

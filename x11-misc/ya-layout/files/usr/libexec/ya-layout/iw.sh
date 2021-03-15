# (c) Denis Kaganovich, under Anarchy license
# tint2 execp for wifi monitor
# use iwmon (iwd) & ip (iproute2), but works with wpa_supplicant too
# re-used ya-nrg for sudo one-point

nrg='sudo -n -- /usr/sbin/ya-nrg'

# 'ip monitor' may be replaced by 'ipmon' without '-n'
# but routes add errors are dirty
ipmon=false

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
unset src3
unset dev
unset dev2
unset dev3
unset via
unset s1
unset freq1
connect=false
preconnect=false
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
#		echo "	$x" >&2
		$connect && conn="$ssid" && connect=false
		[ -v ssid -a "$ssid" = "$conn" ] && show
		nxt
	;;&
	[\<\>]*)
		preconnect=false
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
	'> Event: Disconnect'*)
		unset conn
		show
		$nrg wifi-sleep &
	;;
	'> Event: Connect '*)
		connect=true
		[ -v freq1 ] && {
			[ -v freq ] || freq=$freq1
			unset freq1
		}
	;; # no dhcp
	'Status: 1 (0x00000001)')conn="$ssid";show;; # dhcp
	'SSID: '*)ssid="$y";;
	WPA:|RSN:)t="${x%:}";;
	'Signal mBm: '*)y="000${y#-}";y="${y:(-4):2}";y="${y#0}";mBm="$y";;
	'Frequency: '*)freq="${y%% *}";;
	'Wiphy Frequency: '*)$preconnect && freq1="${y%% *}";;
	'> Complete: Get Scan '*)show;;
	'< Request: Connect '*)preconnect=true;unset freq1;;
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

#!/bin/sh
# (c) Denis Kaganovich, under Anarchy or GPLv2 license
#
# special TYPEs: broken, outdate - to detect broken suspend/swap
# - too different signatures, try only PAGE_SIZE=4096

lsblk(){
	local i
	while read i; do
		i="${i##* }"
		[[ -n "$i" ]] && [[ -e "/dev/$i" ]] && {
			[[ "${i%[0-9]}" == "$i" ]] && grep -q " $i[0-9]*$" /proc/partitions || echo "/dev/$i"
		}
	done </proc/partitions
}

b_id_chk(){
	[[ "$t:$x" == "broken:$ID" ]] && t=outdate
}

b_id(){
	local x y t="$1" l=
	[[ -n "$2" ]] && {
		let x=i+$2
		x="UUID=\"`hexdump -v -s $x -n ${4:-16} -e '"" 4/1 "%02x" "-" 2/1 "%02x" "-" 2/1 "%02x" "-" 2/1 "%02x" "-" 6/1 "%02x" ""' $d`\""
		l="$l $x"
		b_id_chk
	}
	[[ -n "$3" ]] && {
		let x=i+$3
		x=`hexdump -v -s $x -n ${5:-80} -e '"" /1 "%s" ""' $d`
		[[ -n "$x" ]] && {
			x="LABEL=\"$x\""
			b_id_chk
			l=" $x$l"
		}
	}
	[[ -n "$6" ]] && {
		shift 5
		for x in "${@}"; do
			l="$l ${x%%=*}=\""
			x="${x#*=}"
			let y=i+${x%%:*}
			x="${x#*:}"
			l="$l`hexdump -v -s $y -n ${x%%:*} -e '"" /1 "'"${x#*:}"'" ""' $d`\""
		done
	}
	for x in $t; do
		x="TYPE=\"$x\""
		b_id_chk
		[[ "$t" == broken ]] && return
		x="$d:$l $x"
		echo "$x"
		echo "$x" >>$blkid_cache
	done
	OK=true
}

__blkid(){
local OK=false
! grep -s "^$d:" ${blkid_cache:=/dev/null} &&
! ( $blkid "$d"|grep " TYPE=" ) &&
( [[ -b "$d" ]] || [[ -f "$d" ]] ) && {
for i in 0 3 4 8 24 32 54 82 510 536 1016 1024 1030 1040 1048 1080 1560 2048 4086 4096 8182 8192 8212 8244 9564 16374 32758 32768 32769 32777 65526 65536 65588 65600 270336; do
case "`hexdump -v -s $i -n 10 -e '"'$i:'" 10/1 "%x" ""' $d`" in
32:4f52434c4449534b*)b_id oracleasm;;
3:4e54465320202020*)b_id ntfs 69 "" 8;;
1080:53ef*)
	case "`hexdump -v -s 1116 -n 12 -e '"" 1 "%04x" ""' $d`" in
	???[012389ab]00[01][02]000[1-7])u=ext2;;
	????00[01][0246]000[1-7])u=ext3;;
	*[1-7])u=ext4;;
	*)continue;;
	esac
	b_id $u 48 64
;;
8244:5265497345724673*|65588:526549734572324673*|65588:526549734572334673*|65588:5265497345724673*|8212:5265497345724673*)b_id reiserfs 32 48 16 16;;
65536:52654973457234*)b_id reiser4 20 36 16 16;;
65536:1161970*)b_id "gfs2 gfs";;
82:4d5357494e*|82:4641543332202020*|54:4d53444f53*|54:4641543136202020*|54:4641543132202020*|0:eb*|0:e9*|510:55aa*)b_id vfat;;
1040:7f13*|1040:8f13*|1040:6824*|1040:7824*)b_id minix;;
1024:f5fc1a5*)b_id vxfs;;
0:58465342*)b_id xfs 32 108 16 12;;
0:2d726f6d3166732d*)b_id romfs "" 12;;
0:cefa7b1b*)b_id bfs;;
0:453dcd28*)b_id cramfs 16 32 16 16;;
4:514e58344653*)b_id qnx4;;
32769:4245413031*|32769:424f4f5432*|32769:4344303031*|32769:4344573032*|32769:4e53523032*|32769:4e53523033*|32769:5445413031*)b_id udf;;
32777:4344524f4d*|32769:4344303031*)i=32768;b_id iso9660 "" 40 "" 32;;
32768:4a465331*)b_id jfs 136 152 16 16;;
8192:002f5b07b1c*|8192:cb17b0f5200*|270336:002f5b07b1c*|270336:cb17b0f5200*)b_id zfs;;
1024:4244*|1024:482b*|1024:4858*)b_id "hfsplus hfs";;
9564:541910*)b_id ufs;;
8192:49e895f9*)b_id hpfs;;
1016:107e18fd*)b_id sysv;;
4086:535741502d5350414345*|4086:53574150535041434532*|8182:535741502d5350414345*|8182:53574150535041434532*|16374:535741502d5350414345*|16374:53574150535041434532*|32758:535741502d5350414345*|32758:53574150535041434532*|65526:535741502d5350414345*|65526:53574150535041434532*)i=0;b_id swap 1036 1052 16 16;;
4086:533[12]53555350454e44*|4086:554c53555350454e44*|4086:4c494e48494230303031*|8182:533[12]53555350454e44*|8182:554c53555350454e44*|8182:4c494e48494230303031*|16374:533[12]53555350454e44*|16374:554c53555350454e44*|16374:4c494e48494230303031*|32758:533[12]53555350454e44*|32758:554c53555350454e44*|32558:4c494e48494230303031|65526:533[12]53555350454e44*|65526:554c53555350454e44*|65526:4c494e48494230303031)i=0;b_id swsuspend 1036 1052 16 163;;
8:4f7261636c65434653*)b_id ocfs;;
1024:4f4346535632*|2048:4f4346535632*|4096:4f4346535632*|8192:4f4346535632*)b_id ocfs2 336 272 16 64;;
0:4c554b53babe*)b_id crypt_LUKS 168 "" 40;;
0:73717368*|0:68737173*)b_id squashfs;;
536:4c564d3220303031*|24:4c564d3220303031*|1048:4c564d3220303031*|1560:4c564d3220303031*|8192:4f4346535632*)b_id lvm2pv 8 "" 32 "" "LABELONE=-24:8:%s";;
65600:5f42485266535f4d*)b_id btrfs 203 235 16 256;;
1030:3434*)b_id nilfs2 146 226;;
4086:*|8182:*|16374:*|32758:*|65526:*)i=0;b_id broken 1036 1052 16 163;;
esac
done
$OK || {
	i=0
	[[ "$ID" == "TYPE=\"broken\"" ]] && b_id broken 1036 1052 16 163
	[[ "$ID" == "TYPE=\"outdate\"" ]] && b_id outdate 1036 1052 16 163
}
}
}

_blk_ID(){
	ID="$1"
	i=$(_blkid|grep -F "$ID")
	d=""
}

_blkid(){
[[ -z "$*" ]] && set `lsblk` ""
while [[ -n "$*" ]]; do
local d="$1" i="" u
shift
case "$d" in
-p)	blkid_cache="";
	[[ -n "$blkid" ]] && blkid="$blkid $d"
	_blkid "${@}"
	break
;;
-t)	_blk_ID "$(echo "$1"|sed -e 's:^\([A-Z]*=\)\(.*\)$:\1"\2":')"
	shift
;;
-L)	_blk_ID "LABEL=\"$1\""
	shift
;;
-U)	_blk_ID "UUID=\"$1\""
	shift
;;
esac
[[ -n "$d" ]] && i=`__blkid`
[[ -n "$i" ]] && echo "$i" && r=0
done 2>/dev/null
return $r
}

blkid(){
local blkid_cache ID= r=1
[[ -z "$blkid" ]] && {
	blkid="$(which blkid 2>/dev/null || ( [[ -e /bin/blkid ]] && echo /bin/blkid ) || ( [[ -e /sbin/blkid ]] && echo /sbin/blkid ) || echo blkid)"
	[[ -e "$blkid" ]] && ( i="$(readlink $blkid)";[[ "${i%busybox}" == "$i" ]] ) || blkid=false
}
_blkid "${@}"
}

case $0 in
*blkid*)blkid "${@}";exit $?;;
esac

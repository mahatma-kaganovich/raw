#!/bin/sh
# (c) Denis Kaganovich, under Anarchy or GPLv2 license

lsblk(){
	local i
	while read i; do
		i="${i##* }"
		[[ -n "$i" ]] && [[ -e "/dev/$i" ]] && {
			[[ "${i%[0-9]}" == "$i" ]] && grep -q " $i[0-9]*$" /proc/partitions || echo "/dev/$i"
		}
	done </proc/partitions
}

blk_label(){
	local l=`hexdump -v -s $1 -n ${2:-80} -e '"" /1 "%s" ""' $d`
	[[ -n "$l" ]] && echo -n " LABEL=\"$l\""
}

blk_uuid(){
	echo -n ' UUID="'
	hexdump -v -s $1 -n ${2:-16} -e '"" 4/1 "%02x" "-" 2/1 "%02x" "-" 2/1 "%02x" "-" 2/1 "%02x" "-" 6/1 "%02x" ""' $d
	echo -n '"'
}

_blkid(){
! grep -s "^$d:" ${blkid_cache:=/dev/null} &&
! ( $blkid "$d"|grep " TYPE=" ) &&
( [[ -b "$d" ]] || [[ -f "$d" ]] ) && for i in 0 3 4 8 24 32 54 82 510 536 1016 1024 1030 1040 1048 1080 1560 2048 4086 4096 8182 8192 8212 8244 9564 16374 32758 32768 32769 32777 65526 65536 65588 65600 270336; do
case "`hexdump -v -s $i -n 10 -e '"'$i:'" 10/1 "%x" ""' $d`" in
32:4f52434c4449534b*)echo oracleasm;;
3:4e54465320202020*)echo ntfs;;
1080:53ef*)
	case "`hexdump -v -s 1116 -n 12 -e '"" 1 "%04x" ""' $d`" in
	???[012389ab]00[01][02]000[1-7])echo -n ext2;;
	????00[01][0246]000[1-7])echo -n ext3;;
	*[1-7])echo -n ext4;;
	*)echo -n jbd;;
	esac
	blk_uuid 1128;blk_label 1144;echo ""
;;
8244:5265497345724673*|65588:526549734572324673*|65588:526549734572334673*|65588:5265497345724673*|8212:5265497345724673*)echo reiserfs;;
65536:52654973457234*)echo reiser4;;
65536:1161970*)echo "gfs2
gfs";;
82:4d5357494e*|82:4641543332202020*|54:4d53444f53*|54:4641543136202020*|54:4641543132202020*|0:eb*|0:e9*|510:55aa*)echo vfat;;
1040:7f13*|1040:8f13*|1040:6824*|1040:7824*)echo minix;;
1024:f5fc1a5*)echo vxfs;;
0:58465342*)echo xfs;;
0:2d726f6d3166732d*)echo romfs;;
0:cefa7b1b*)echo bfs;;
0:453dcd28*)echo cramfs;;
4:514e58344653*)echo qnx4;;
32769:4245413031*|32769:424f4f5432*|32769:4344303031*|32769:4344573032*|32769:4e53523032*|32769:4e53523033*|32769:5445413031*)echo udf;;
32777:4344524f4d*|32769:4344303031*)echo iso9660;;
32768:4a465331*)echo jfs;;
8192:002f5b07b1c*|8192:cb17b0f5200*|270336:002f5b07b1c*|270336:cb17b0f5200*)echo zfs;;
1024:4244*|1024:482b*|1024:4858*)echo "hfsplus
hfs";;
9564:541910*)echo ufs;;
8192:49e895f9*)echo hpfs;;
1016:107e18fd*)echo sysv;;
4086:535741502d5350414345*|4086:53574150535041434532*|8182:535741502d5350414345*|8182:53574150535041434532*|16374:535741502d5350414345*|16374:53574150535041434532*|32758:535741502d5350414345*|32758:53574150535041434532*|65526:535741502d5350414345*|65526:53574150535041434532*)echo swap;;
4086:533[12]53555350454e44*|4086:554c53555350454e44*|8182:533[12]53555350454e44*|8182:554c53555350454e44*|16374:533[12]53555350454e44*|16374:554c53555350454e44*|32758:533[12]53555350454e44*|32758:554c53555350454e44*|65526:533[12]53555350454e44*|65526:554c53555350454e44*)echo swsuspend;;
8:4f7261636c65434653*)echo ocfs;;
1024:4f4346535632*|2048:4f4346535632*|4096:4f4346535632*|8192:4f4346535632*)echo ocfs2;;
0:4c554b53babe*)echo crypt_LUKS;;
0:73717368*|0:68737173*)echo squashfs;;
536:4c564d3220303031*|24:4c564d3220303031*|1048:4c564d3220303031*|1560:4c564d3220303031*|8192:4f4346535632*)echo lvm2pv;;
65600:5f42485266535f4d*)echo btrfs;;
1030:3434*)echo -n nilfs2;blk_uuid 1176;blk_label 1256;echo "";;
esac|while read i u; do
	i="$d:${u:+ }$u TYPE=\"$i\""
	echo "$i"
	echo "$i" >>$blkid_cache
done
done
}

blkid(){
local r=1 blkid_cache
[[ -z "$blkid" ]] && {
	blkid="$(which blkid 2>/dev/null || ( [[ -e /bin/blkid ]] && echo /bin/blkid ) || ( [[ -e /sbin/blkid ]] && echo /sbin/blkid ) || echo blkid)"
	[[ -e "$blkid" ]] && ( i="$(readlink $blkid)";[[ "${i%busybox}" == "$i" ]] ) || blkid=false
}
[[ -z "$*" ]] && set `lsblk` ""
while [[ -n "$*" ]]; do
local d="$1" i="" u
shift
case "$d" in
-t)	i=$(blkid|grep -F "${1%%=*}=\"${1#*=}\"")
	shift
	d=""
;;
esac
[[ -n "$d" ]] && i=`_blkid`
[[ -n "$i" ]] && echo "$i" && r=0
done 2>/dev/null
return $r
}

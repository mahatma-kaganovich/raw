#!/bin/bash

x=`grep "^flags	" /proc/cpuinfo|sort -u`
x="${x#*:}"
{
f1=
f2=
for i in $x; do
	i1="$i"
	case "$i" in
	sse|3dnowext)f1+=" $i mmxext";;
	pni)f1+=" sse3";;
	*)
		if (grep "^$i1 " /usr/portage/profiles/use.desc ; grep "^[^ 	]*:$i " /usr/portage/profiles/use.local.desc)|grep -q 'CPU\|processor\|chip\|instruction'; then
			f1+=" $i"
		else
			f2+=" $i"
		fi
	;;
	esac
done
echo "USE=\"\$USE $f1\""
echo "CPU_FLAGS_X86=\"\$CPU_FLAGS_X86 $f1 $f2\""
i="/cc1 -quiet -v help-dummy "
j=
if j=`gcc -march=native --help=target -v 2>&1 |grep -F "$i"`; then
	j="${j#*$i}"
	j="${j% -quiet *}"
	if i=`gcc -march=native --help=target -v 2>&1 |grep -F "/as "`; then
		i="${i#* -mtune=}"
		i="${i%% *}"
		j="$j -Wa,-mtune=$i"
	fi
fi
echo "CPUFLAGS=\"$j\""
if i=`grep "^processor[ 	]*: " /proc/cpuinfo`; then
	i="${i##*: }"
	i=$[i+1]
	echo "ncpu=$i"
	i=$[i+1]
	echo "ncpu1=$i"
	echo "MAKEOPTS=\"-j$i -s\""
fi
} >/etc/portage/make.conf.cpu

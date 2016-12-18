#!/bin/bash

d=`pwd`
cd /usr/portage/metadata/md5-cache

pkg(){
	local p="$1" x
	while [[ "$p" == */*-* ]]; do
		p="${p%-*}"
		x="/usr/portage/$p/${1#*/}*.ebuild"
		[ "$(echo $x)" != "$x" ] && echo "$p"
	done
}

l=$(grep -lF ' qt5 ' */*) || exit 1

for i in $(grep -l '^IUSE=.*+qt4' $l); do
	grep -q '^IUSE=.*qt5' "$i" &&
	for p in $(pkg "$i"); do
		echo "$p qt5"
	done
done | uniq >$d/package.use.tmp

for i in `grep -l '\(\^\^\|??\) ([^()]* qt5 [^()]*)' $l`; do
	grep -oh '\(\^\^\|??\) ([^()]* qt5 [^()]*)' "$i"|sed -e 's:^....::' -e 's:.$::' -e 's: qt5 : :' -e 's: $::'|while read q; do
		[ -n "$q" ] &&
		for p in $(pkg "$i"); do
			false &&
			[ "$q" != qt4 ] && {
				echo "# $p $q"
				[[ "$q" != *qt4* ]] && continue
				q=" $q "
				q="${q// gtk3 / }"
			}
			echo "$p $q"
		done
	done
done | uniq >$d/package.use.mask.tmp

cd $d || exit 1

cmp package.use{,.tmp} && unlink package.use.tmp
cmp package.use.mask{,.tmp} && unlink package.use.mask.tmp
rename .tmp '' package.*.tmp



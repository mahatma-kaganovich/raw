#!/bin/bash

cd /usr/portage/metadata/md5-cache
for i1 in $(grep -l "^IUSE=.*+qt4" */*); do
	e=qt5
#	for e in qt5 gtk gtk2 gtk3; do
	for e in qt5; do
		grep -q "^IUSE=.*+$e" "$i1" && continue 2
		grep -q "^IUSE=.*$e" "$i1" || continue
		i="$i1"
		while [[ "$i" == */*-* ]]; do
			i="${i%-*}"
			[ -e /usr/portage/$i ] && echo "$i $e" && continue 3
		done
		echo "=$i $e"
		continue 2
	done
	echo "# $i1 `grep "^IUSE=" "$i1"`" >&2
done|sort -u

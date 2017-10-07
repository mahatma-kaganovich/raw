[ -n "$D" ] && [ -e "$D" ] && for i in "${D}"/usr/lib*; do
	l="../$(readlink "$i/libilbc.so")" &&
	mkdir "$i/libilbc" &&
	ln -s "$l" "$i/libilbc/libilbc.so" &&
	[ -e "$i/libilbc/libilbc.so" ] &&
	rm "$i/libilbc.so" &&
	sed -i -e 's:} -lilbc:} -L${libdir}/libilbc -lilbc:' "$i/pkgconfig/libilbc.pc"
done


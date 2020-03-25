# 710840
export with_cmocka=no
# 701114
for i in "${S}"/lib/*; do
	[ -d "$i" ] && append-ldflags -L"${i}"/.libs
done

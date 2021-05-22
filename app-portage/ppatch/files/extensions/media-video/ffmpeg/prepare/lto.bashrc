f=
# ebuild filtering -flto*
for i in $CFLAGS; do
	[[ "$i" == -flto-* ]] && f+=" $i"
done
[ -n "$f" ] && sed -i -e "s:flags *-flto:flags $f -flto:" "${S}/configure"

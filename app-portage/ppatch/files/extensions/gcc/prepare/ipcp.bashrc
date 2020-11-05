[[ "$PV" == [789].* ]] && [[ "$CFLAGS" == *=ipa-cp-unit-growth=* ]] && {
	echo "renaming param ipcp-unit-growth to ipa-cp-unit-growth for gcc 10 compatibility"
	sed -i -e s:ipcp-unit-growth:ipa-cp-unit-growth:g $(grep -Rl ipcp-unit-growth "${S}")
}

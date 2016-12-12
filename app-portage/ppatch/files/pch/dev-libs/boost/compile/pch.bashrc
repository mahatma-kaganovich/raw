o=( )
for i in "${OPTIONS[@]}"; do
	[ "$i" = pch=off ] && o+=( pch=on ) || o+=( $i )
done
OPTIONS=$o
echo "${OPTIONS[@]}"
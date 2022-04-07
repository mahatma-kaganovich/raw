[[ "$IUSE" == *gallium* ]] &&
use osmesa && use gallium && use !classic && {
	export enable_gallium_osmesa=yes
	export enable_osmesa=no
	sed -i -e 's:enable_osmesa="$enableval":enable_osmesa=no:g' "$S"/configure{,.ac}
}

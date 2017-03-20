
# native defaults are experemental while arch_16 (-m16) not separated
# keep only -mtune= as unsure, but maniacal little performance hack.
# -mfpmath= possible too, but keep it reasonable safe.

for i in $CFLAGS; do
	case "$i" in
	-mtune=*)
		i="${i#-m}"
		j="${i%%=*}"
		export with_${j//-/_}="${i#*=}"
        ;;
        esac
done

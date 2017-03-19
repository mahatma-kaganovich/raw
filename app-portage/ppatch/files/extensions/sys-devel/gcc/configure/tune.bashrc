
# native defaults are experemental while arch_16 (-m16) not separated
# keep only -mtune= as unsure, but maniacal little performance hack.
# -mfpmath= possible too, but keep it reasonable safe.

#for i in $CFLAGS; do
# prefer decoded -mtune=native to skip multiple detections
for i in $CFLAGS $CFLAGS_CPU; do 
	case "$i" in
#	-m*=*)
	-mtune=*)
		i="${i#-m}"
		j="${i%%=*}"
		export with_${j//-/_}="${i#*=}"
        ;;
        esac
done

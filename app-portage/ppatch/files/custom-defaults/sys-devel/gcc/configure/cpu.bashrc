
# CFLAGS -m<option>=<value> -> env with_<option>=<value>
# to hardcode some GCC defaults (default -march=native, for example)
# experimental

for i in $CFLAGS; do
#for i in $CFLAGS $CFLAGS_CPU; do  # faster to configure
	case "$i" in
	-m*=*)
		i="${i#-m}"
		j="${i%%=*}"
		export with_${j//-/_}="${i#*=}"
	;;
	esac
done

export CFLAGS_BASE
export CXXFLAGS_BASE
append-flags -DNDEBUG=1
for i in "$WORKDIR"/*/config.make; do
	for j in CC CXX CFLAGS; do
		sed -i -e "s:^\($j .*\)$:\1 $CXXFLAGS:" "$i"
	done
done
export CFLAGS="$CFLAGS_BASE" CXXFLAGS="$CXXFLAGS_BASE" LDFLAGS="$LDFLAGS_BASE"

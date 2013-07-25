for i in "$BUILD_PREFIX"/sys-fs/aufs3-*/temp/aufs3-standalone/aufs3-standalone-base-combined.patch; do
	true
done
cd "$S" || die
if ! [ -e "${i##*/}" ]; then
	cp "$i" . || bzip2 -dc "$ROOT"/usr/share/doc/aufs3*/aufs3-standalone-base-combined.patch.bz2 >"${i##*/}"
	epatch "${i##*/}" || die
fi

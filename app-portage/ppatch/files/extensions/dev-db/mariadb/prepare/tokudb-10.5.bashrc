[ -e "$S/storage/tokudb" ] && [[ "$IUSE" != *tokudb* ]] && use extraengine && {
einfo "Prepare TokuDB"
# Don't build bundled xz-utils for tokudb
echo > "${S}/storage/tokudb/PerconaFT/cmake_modules/TokuThirdParty.cmake" || die
sed -i -e 's/ build_lzma//' -e 's/ build_snappy//' "${S}/storage/tokudb/PerconaFT/ft/CMakeLists.txt" || die
sed -i -e 's/add_dependencies\(tokuportability_static_conv build_jemalloc\)//' "${S}/storage/tokudb/PerconaFT/portability/CMakeLists.txt" || die
}

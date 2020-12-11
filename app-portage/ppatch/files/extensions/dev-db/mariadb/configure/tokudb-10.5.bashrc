[ -e "$S/storage/tokudb" ] && [[ "$IUSE" != *tokudb* ]] && use extraengine && {
einfo "Configure TokuDB"
export MYCMAKEARGS+=' -DPLUGIN_TOKUDB=YES -DTOKUDB_OK=1'
}
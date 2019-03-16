[[ " $IUSE " == *' sunec '* ]] && use sunec && sed -i -e 's:^#\(security\.provider\.10=sun\.security\.pkcs11\.SunPKCS11\):\1:' `find "${S}" -name java.security`

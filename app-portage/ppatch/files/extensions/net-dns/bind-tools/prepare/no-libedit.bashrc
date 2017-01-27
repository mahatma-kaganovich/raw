[[ "$USE" == *libedit* ]] || sed -i -e 's: -ledit : :' "${S}"/configure.*

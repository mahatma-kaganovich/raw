sed -i -e 's: -lilbc\( \|$\): "$(pkg-config --libs libilbc)" :' "${S}/configure"

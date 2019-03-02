sed -i -e 's:\$(CXXFLAGS) -march=:$(subst -march=native,-mtune=native,$(CXXFLAGS)) -march=:' "${S}"/src/gui/Makefile

strip-flags(){
local n i j f ALLOWED_FLAGS
_setup-allowed-flags
for n in {C,CXX,F,FC,LD}FLAGS; do
f=
for i in ${!n}; do
    case "$i" in
    -O?|-pipe|-W*|-m*|--*);;
    -fsched*|-fira-*|-flive-range-shrinkage);;
    -fno-ident|-fdiagnostics-column-unit=*);;
    -flimit-function-alignment);;
    -frename-registers|-fweb);;
    -fno-semantic-interposition)[ "$PN" = glibc ] && continue;;
    -falign-*=*);;
    *predictive-commoning*);;
    -fipa-reorder-for-locality);;
    -fgcse*|-f*-cost-model=*);;
    -flto*|-f*-lto-*|-f*-ltrans);;
    -fzero-init-padding-bits=unions|-std=*)[ "$PN" = gcc ] && continue;;
    *)for j in "${ALLOWED_FLAGS[@]}" ; do
        [[ "$i" == $j ]] && f+=" $i" && break
    done
    continue;;
    esac
    f+=" $i"
done
export $n="${f# }"
done
}

filter-lto(){
	filter-flags '-flto*' -fwhole-program-vtables '-fsanitize=cfi*'
	append-flags $(test-flags-CC -fipa-reorder-for-locality)
}

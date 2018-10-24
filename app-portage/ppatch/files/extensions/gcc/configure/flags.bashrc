setup-allowed-flags
[ -n "$ALLOWED_FLAGS" ] && {
ALLOWED_FLAGS_=( ${ALLOWED_FLAGS[@]} -fmodulo-sched '-mtls-dialect=*' -mtls-dialect )
# 2test
#ALLOWED_FLAGS_=( ${ALLOWED_FLAGS[@]} -fmodulo-sched '-mtls-dialect=*' -mtls-dialect -flto -ffat-lto-objects )
export ALLOWED_FLAGS_
setup-allowed-flags(){
	ALLOWED_FLAGS=( ${ALLOWED_FLAGS_[@]} )
	return 0
}
export -f setup-allowed-flags
}

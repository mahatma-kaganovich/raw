setup-allowed-flags
[ -n "$ALLOWED_FLAGS" ] && {
export ALLOWED_FLAGS="$ALLOWED_FLAGS -fmodulo-sched -mtls-dialect=* -mtls-dialect"
setup-allowed-flags(){
	return 0
}
export -f setup-allowed-flags
}

# once there are "digest" - there are "digest", not "broken". force "stale=true" to avoid random password requests
sed -i -e 's/digest_user->auth_type = Auth::AUTH_BROKEN;/digest_user->auth_type = Auth::AUTH_DIGEST;/' "$S/src/auth/digest/auth_digest.cc"
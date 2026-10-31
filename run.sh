#!/bin/sh
set -eu
umask 077

state=${COGNATE_LAZYCAT_STATE:-/lzcapp/var/cognate}
for directory in "$state" "$state/keys" "$state/data"; do
  if [ -L "$directory" ]; then
    printf 'Unsafe Cognate state directory\n' >&2
    exit 1
  fi
  mkdir -p "$directory"
  chmod 700 "$directory"
done

key="$state/keys/master.key"
if [ -L "$key" ]; then
  printf 'Unsafe Cognate master key\n' >&2
  exit 1
fi
if [ ! -e "$key" ]; then
  candidate=$(mktemp "$state/keys/.master.XXXXXXXX")
  trap 'rm -f "$candidate"' 0
  head -c 32 /dev/urandom > "$candidate"
  if ! ln "$candidate" "$key"; then
    printf 'Cognate master key creation unconfirmed\n' >&2
    exit 1
  fi
  rm -f "$candidate"
  trap - 0
fi

if [ -z "${LAZYCAT_APP_DOMAIN:-}" ] || [ -z "${LAZYCAT_AUTH_OIDC_ISSUER_URI:-}" ] || [ -z "${LAZYCAT_AUTH_OIDC_CLIENT_ID:-}" ]; then
  printf 'LazyCat domain or OIDC configuration missing\n' >&2
  exit 1
fi
export COGNATE_OIDC_ISSUER="$LAZYCAT_AUTH_OIDC_ISSUER_URI"
export COGNATE_OIDC_CLIENT_ID="$LAZYCAT_AUTH_OIDC_CLIENT_ID"
export COGNATE_OIDC_CLIENT_SECRET_FILE=''
if [ -n "${LAZYCAT_AUTH_OIDC_CLIENT_SECRET:-}" ]; then
  if [ -L "$state/keys/oidc.secret" ] || { [ -e "$state/keys/oidc.secret" ] && [ ! -f "$state/keys/oidc.secret" ]; }; then
    printf 'Unsafe Cognate OIDC secret file\n' >&2
    exit 1
  fi
  secret=$(mktemp "$state/keys/.oidc.XXXXXXXX")
  trap 'rm -f "$secret"' 0
  printf '%s' "$LAZYCAT_AUTH_OIDC_CLIENT_SECRET" > "$secret"
  mv -f "$secret" "$state/keys/oidc.secret"
  trap - 0
  export COGNATE_OIDC_CLIENT_SECRET_FILE="$state/keys/oidc.secret"
fi
unset LAZYCAT_AUTH_OIDC_CLIENT_SECRET

exec "$(dirname "$0")/cognate-server" \
  --data-dir "$state/data" \
  --key-file "$key" \
  --listen 127.0.0.1:8080 \
  --public-origin "https://$LAZYCAT_APP_DOMAIN"

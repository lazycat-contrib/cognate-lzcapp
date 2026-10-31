#!/bin/sh
set -eu
umask 077

state=${COGNATE_LAZYCAT_STATE:-/lzcapp/var/cognate}
case "$state" in
  /*) ;;
  *) printf 'Cognate state directory must be absolute\n' >&2; exit 1 ;;
esac
if [ -L "$state" ]; then
  printf 'Unsafe Cognate state directory\n' >&2
  exit 1
fi
mkdir -p "$state"
state=$(cd "$state" && pwd -P)
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

if [ -z "${LAZYCAT_APP_DOMAIN:-}" ]; then
  printf 'LazyCat application domain missing\n' >&2
  exit 1
fi
export COGNATE_OIDC_ISSUER=''
export COGNATE_OIDC_CLIENT_ID=''
export COGNATE_OIDC_CLIENT_SECRET_FILE=''
case "${COGNATE_LAZYCAT_OIDC_ENABLED:-true}" in
  true)
    if [ -z "${LAZYCAT_AUTH_OIDC_ISSUER_URI:-}" ] || [ -z "${LAZYCAT_AUTH_OIDC_CLIENT_ID:-}" ]; then
      printf 'LazyCat OIDC configuration missing\n' >&2
      exit 1
    fi
    export COGNATE_OIDC_ISSUER="$LAZYCAT_AUTH_OIDC_ISSUER_URI"
    export COGNATE_OIDC_CLIENT_ID="$LAZYCAT_AUTH_OIDC_CLIENT_ID"
    ;;
  false) ;;
  *) printf 'Invalid OIDC setting\n' >&2; exit 1 ;;
esac
if [ "${COGNATE_LAZYCAT_OIDC_ENABLED:-true}" = true ] && [ -n "${LAZYCAT_AUTH_OIDC_CLIENT_SECRET:-}" ]; then
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

set -- "$(dirname "$0")/cognate-server" \
  --data-dir "$state/data" \
  --key-file "$key" \
  --listen 127.0.0.1:8080 \
  --public-origin "https://$LAZYCAT_APP_DOMAIN"
if [ -n "${COGNATE_BOOTSTRAP_ADMIN_USERNAME:-}" ]; then
  if [ -L "$state/keys/bootstrap.secret" ] || { [ -e "$state/keys/bootstrap.secret" ] && [ ! -f "$state/keys/bootstrap.secret" ]; }; then
    printf 'Unsafe Cognate administrator password file\n' >&2
    exit 1
  fi
  if [ -n "${COGNATE_BOOTSTRAP_ADMIN_PASSWORD:-}" ]; then
    secret=$(mktemp "$state/keys/.bootstrap.XXXXXXXX")
    trap 'rm -f "$secret"' 0
    printf '%s' "$COGNATE_BOOTSTRAP_ADMIN_PASSWORD" > "$secret"
    mv -f "$secret" "$state/keys/bootstrap.secret"
    trap - 0
  fi
  set -- "$@" --bootstrap-admin-username "$COGNATE_BOOTSTRAP_ADMIN_USERNAME" \
    --bootstrap-admin-password-file "$state/keys/bootstrap.secret"
fi
unset COGNATE_BOOTSTRAP_ADMIN_USERNAME COGNATE_BOOTSTRAP_ADMIN_PASSWORD
count=0
previous_ifs=$IFS
IFS=', '
set -f
for administrator in ${COGNATE_ADMIN_USER_IDS:-}; do
  if ! printf '%s' "$administrator" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
    printf 'Invalid administrator account ID setting\n' >&2
    exit 1
  fi
  count=$((count + 1))
  if [ "$count" -gt 32 ]; then
    printf 'Too many administrator account IDs\n' >&2
    exit 1
  fi
  set -- "$@" --admin-user-id "$administrator"
done
IFS=$previous_ifs
unset COGNATE_ADMIN_USER_IDS
exec "$@"

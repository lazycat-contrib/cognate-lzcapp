#!/bin/sh
set -eu
umask 077

bootstrap_password_encoded=${COGNATE_BOOTSTRAP_ADMIN_PASSWORD_BASE64:-}
unset COGNATE_BOOTSTRAP_ADMIN_PASSWORD_BASE64 COGNATE_BOOTSTRAP_ADMIN_PASSWORD
decode_setting() {
  printf '%s' "$1" | base64 -d && printf '.'
}
if [ "${COGNATE_BOOTSTRAP_ADMIN_USERNAME_BASE64+x}" = x ]; then
  decoded=$(decode_setting "$COGNATE_BOOTSTRAP_ADMIN_USERNAME_BASE64") || { printf 'Invalid encoded administrator username\n' >&2; exit 1; }
  COGNATE_BOOTSTRAP_ADMIN_USERNAME=${decoded%.}
fi
if [ "${COGNATE_ADMIN_USER_IDS_BASE64+x}" = x ]; then
  decoded=$(decode_setting "$COGNATE_ADMIN_USER_IDS_BASE64") || { printf 'Invalid encoded administrator IDs\n' >&2; exit 1; }
  COGNATE_ADMIN_USER_IDS=${decoded%.}
fi
if [ "${COGNATE_GITHUB_CLIENT_ID_BASE64+x}" = x ]; then
  decoded=$(decode_setting "$COGNATE_GITHUB_CLIENT_ID_BASE64") || { printf 'Invalid encoded GitHub client ID\n' >&2; exit 1; }
  export COGNATE_GITHUB_CLIENT_ID="${decoded%.}"
fi
unset decoded COGNATE_BOOTSTRAP_ADMIN_USERNAME_BASE64 COGNATE_BOOTSTRAP_ADMIN_PASSWORD_BASE64 COGNATE_ADMIN_USER_IDS_BASE64 COGNATE_GITHUB_CLIENT_ID_BASE64

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
  if [ "$(wc -c < "$candidate")" -ne 32 ]; then
    printf 'Cognate master key generation returned an invalid size\n' >&2
    exit 1
  fi
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
  if [ -n "$bootstrap_password_encoded" ]; then
    secret=$(mktemp "$state/keys/.bootstrap.XXXXXXXX")
    trap 'rm -f "$secret"' 0
    if ! printf '%s' "$bootstrap_password_encoded" | base64 -d > "$secret"; then
      printf 'Invalid encoded administrator password\n' >&2
      exit 1
    fi
    mv -f "$secret" "$state/keys/bootstrap.secret"
    trap - 0
  fi
  set -- "$@" --bootstrap-admin-username "$COGNATE_BOOTSTRAP_ADMIN_USERNAME" \
    --bootstrap-admin-password-file "$state/keys/bootstrap.secret"
fi
unset bootstrap_password_encoded COGNATE_BOOTSTRAP_ADMIN_USERNAME COGNATE_BOOTSTRAP_ADMIN_PASSWORD
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
printf 'Cognate storage diagnostics: effective_uid=%s\n' "$(id -u)" >&2
if metadata=$(stat -c 'mode=%a uid=%u gid=%g links=%h bytes=%s' "$key" 2>/dev/null); then
  printf 'Cognate storage diagnostics: master_key %s (content never logged)\n' "$metadata" >&2
else
  printf 'Cognate storage diagnostics: master_key metadata unavailable\n' >&2
fi
current="$state/keys"
level=0
while [ "$level" -lt 64 ]; do
  if metadata=$(stat -c 'mode=%a uid=%u gid=%g type=%F' "$current" 2>/dev/null); then
    printf 'Cognate storage diagnostics: directory_level=%s %s\n' "$level" "$metadata" >&2
  else
    printf 'Cognate storage diagnostics: directory_level=%s metadata unavailable\n' "$level" >&2
  fi
  parent=$(dirname "$current")
  if [ "$parent" = "$current" ]; then
    break
  fi
  current=$parent
  level=$((level + 1))
done
exec "$@"

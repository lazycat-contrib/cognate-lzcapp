#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
cd "$root"
. ./upstream.env

test "$(go env GOVERSION)" = go1.27.3
test "$(node --version)" = v26.12.0
test "${LAZYCAT_TARGET_OS:-linux}" = linux
case "${LAZYCAT_TARGET_ARCH:-amd64}" in
  amd64|arm64) ;;
  *) printf 'Unsupported LazyCat architecture\n' >&2; exit 1 ;;
esac

if [ ! -d .source/.git ]; then
  git clone --depth 1 --branch "$SOURCE_TAG" "$SOURCE_REPOSITORY" .source
fi
test "$(git -C .source rev-parse HEAD)" = "$SOURCE_COMMIT"
test -z "$(git -C .source status --porcelain --untracked-files=no)"

npm ci --prefix .source/web
npm run typecheck --prefix .source/web
npm run build --prefix .source/web
mkdir -p dist/content
(
  cd .source
  GOOS=linux GOARCH="${LAZYCAT_TARGET_ARCH:-amd64}" CGO_ENABLED=0 \
    go build -mod=readonly -trimpath -o "$root/dist/content/cognate-server" ./cmd/cognate-server
)
install -m 0755 run.sh dist/content/run.sh
install -m 0644 .source/LICENSE dist/content/LICENSE
install -m 0644 .source/internal/codexconfig/testdata/native-0.166.0/LICENSE dist/content/CODEX-0.166.0-LICENSE.txt
printf '%s\n' "$SOURCE_COMMIT" > dist/content/SOURCE_COMMIT
metadata=$(go version -m dist/content/cognate-server)
for setting in CGO_ENABLED=0 GOOS=linux "GOARCH=${LAZYCAT_TARGET_ARCH:-amd64}" "vcs.revision=$SOURCE_COMMIT" vcs.modified=false; do
  grep -qFx "$(printf '\tbuild\t%s' "$setting")" <<< "$metadata"
done

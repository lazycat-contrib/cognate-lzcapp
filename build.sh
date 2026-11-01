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

gemini=.source/internal/geminiconfig/testdata/native-profile-v0.61.0
test -f "$gemini/LICENSE" && test ! -L "$gemini/LICENSE"
test -f "$gemini/THIRD_PARTY_NOTICES" && test ! -L "$gemini/THIRD_PARTY_NOTICES"
printf '%s  %s\n' \
  58d1e17ffe5109a7ae296caafcadfdbe6a7d176f0bc4ab01e12a689b0499d8bd "$gemini/LICENSE" \
  fb2528fa004c7597e258b80c46370e27c5fe74565f6afb64228a4e8ac0e5037c "$gemini/THIRD_PARTY_NOTICES" | sha256sum -c -

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
install -m 0644 "$gemini/LICENSE" dist/content/GEMINI-0.61.0-LICENSE.txt
install -m 0644 "$gemini/THIRD_PARTY_NOTICES" dist/content/GEMINI-0.61.0-THIRD_PARTY_NOTICES.txt
printf '%s\n' "$SOURCE_COMMIT" > dist/content/SOURCE_COMMIT
metadata=$(go version -m dist/content/cognate-server)
for setting in CGO_ENABLED=0 GOOS=linux "GOARCH=${LAZYCAT_TARGET_ARCH:-amd64}" "vcs.revision=$SOURCE_COMMIT" vcs.modified=false; do
  grep -qFx "$(printf '\tbuild\t%s' "$setting")" <<< "$metadata"
done

#!/usr/bin/env bash
# SAFELOCAL: build de safeline-mgt "local-pure" en linux/arm64.
# Compile dans un conteneur arm64 natif (Docker Desktop sur Apple Silicon),
# sans cross-compilation CGO. Source montee en lecture seule, copie de travail
# dans le conteneur : go.mod/go.sum du depot ne sont jamais touches.
# Resultat : image safeline-mgt:local-pure-arm64
# Prerequis : image golang:1.25.14 (arm64), cache de modules Go local
# (GOPROXY=off), image de base chaitin/safeline-mgt-g-arm:latest (arm64).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/.build-local/runtime/out-arm64"
CTX="$ROOT/.build-local/runtime/mgt-image-ctx-arm64"
GOMOD="$(go env GOMODCACHE)"
mkdir -p "$OUT" "$CTX/bin"
# go.mod/go.sum propres (HEAD), sans modifier le depot
git -C "$ROOT" show HEAD:management/webserver/go.mod > "$OUT/go.mod.orig"
git -C "$ROOT" show HEAD:management/webserver/go.sum > "$OUT/go.sum.orig"

docker run --rm --platform linux/arm64 \
  -v "$ROOT":/src:ro -v "$GOMOD":/go/pkg/mod -v "$OUT":/out golang:1.25.14 bash -euc '
    export GOTOOLCHAIN=local GOPROXY=off GOFLAGS=-mod=mod CGO_ENABLED=1
    mkdir -p /work && cp -r /src/management/webserver /work/webserver
    cd /work/webserver
    FVM=/src/.build-local/fvm
    mkdir -p submodule/fvm/lib
    gcc -static -I "$FVM/include" -fPIC -c "$FVM/stub.c" -o /tmp/stub.o
    ar rcs submodule/fvm/lib/libfvm.a /tmp/stub.o
    export CGO_CFLAGS="-I$FVM/include"
    export CGO_LDFLAGS="-L$PWD/submodule/fvm/lib -lfvm"
    cp /out/go.mod.orig go.mod; cp /out/go.sum.orig go.sum
    cat >> go.mod <<EOT

replace chaitin.cn/dev/go/errors => /src/.build-local/stubs/errors
replace chaitin.cn/dev/go/log => /src/.build-local/stubs/log
replace chaitin.cn/dev/go/settings => /src/.build-local/stubs/settings
EOT
    go build -ldflags "-extldflags \"-static\"" -o /out/mgt-safeline-arm64 .
    file /out/mgt-safeline-arm64 || true
  '

cp -f "$OUT/mgt-safeline-arm64" "$CTX/bin/mgt"
cat > "$CTX/Dockerfile" <<'EOT'
FROM chaitin/safeline-mgt-g-arm:latest
COPY bin/mgt /app/mgt
RUN chmod +x /app/mgt
EOT
docker build --platform linux/arm64 -t safeline-mgt:local-pure-arm64 "$CTX"
echo "[build-arm64] OK -> safeline-mgt:local-pure-arm64"

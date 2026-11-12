#!/bin/sh
# BuildBeacon — smoke test of the Docker image: first start, interface, API, save, HTTPS.
# File version: 1.1 (2026-11-12) — comments and messages in English.
#
# Usage (at the repository root): hub/tool/docker_smoke_test.sh [image] [port]
# Run by the CI after building the image; also usable locally.
set -eu

image=${1:-buildbeacon-hub}
port=${2:-18080}
name="buildbeacon-smoke-$$"
url="http://127.0.0.1:$port"

docker run -d --name "$name" -p "$port:8080" -e BB_LANG=fr "$image" >/dev/null
cleanup() {
  echo "--- log of the Hub"
  docker logs "$name" 2>&1 || true
  docker rm -f "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

step() { echo "== $*"; }
json() { python3 -c "import json, sys; d = json.load(sys.stdin); $1"; }
wait_ready() {
  i=0
  until curl -fsS "$url/api/health" >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -le 30 ] || { echo "the Hub does not answer"; exit 1; }
    sleep 1
  done
}

step "start"
wait_ready
curl -fsS "$url/api/health" | json "print(d['name'], d['version'])"

step "first start: config.json created with the master tile only"
curl -fsS "$url/api/config" |
  json "assert [t['kind'] for t in d['tiles']] == ['master'], d"

step "web interface served, revalidated on every visit"
curl -fsS "$url/" | grep -q flutter_bootstrap.js
curl -fsSI "$url/main.dart.js" | grep -qi '^cache-control: no-cache'

step "saving a configuration (/data volume writable)"
curl -fsS -X PUT "$url/api/config" -H 'Content-Type: application/json' \
  --data-binary @config.example.json | json "assert d['changed'], d"

step "restart: the saved configuration is kept"
docker restart "$name" >/dev/null
wait_ready
curl -fsS "$url/api/config" | json "assert len(d['tiles']) == 3, d"

step "HTTPS to GitHub (certificates of the image)"
i=0
until curl -fsS "$url/api/state" | json "
sources = d['sources'].values()
read = [s for s in sources if s['updated_at']]
errors = [s['error']['en'] for s in sources if s['error']]
# Any answer from GitHub, even "quota exhausted", proves that TLS works.
quota = [e for e in errors if 'quota' in e or '403' in e]
if not (read or quota):
    raise SystemExit(1)
print(len(read), 'source(s) read', errors)"; do
  i=$((i + 1))
  [ "$i" -le 30 ] || {
    curl -fsS "$url/api/state" | json "print([s['error'] for s in d['sources'].values()])"
    exit 1
  }
  sleep 1
done

echo "== image OK"

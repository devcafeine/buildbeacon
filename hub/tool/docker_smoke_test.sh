#!/bin/sh
# BuildBeacon — essai de l'image Docker : premier démarrage, interface, API, enregistrement, HTTPS.
# Version du fichier : 1.0 (2026-11-12)
#
# Usage (à la racine du dépôt) : hub/tool/docker_smoke_test.sh [image] [port]
# Lancé par la CI après la construction de l'image ; utilisable en local.
set -eu

image=${1:-buildbeacon-hub}
port=${2:-18080}
name="buildbeacon-smoke-$$"
url="http://127.0.0.1:$port"

docker run -d --name "$name" -p "$port:8080" -e BB_LANG=fr "$image" >/dev/null
cleanup() {
  echo "--- journal du Hub"
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
    [ "$i" -le 30 ] || { echo "le Hub ne répond pas"; exit 1; }
    sleep 1
  done
}

step "démarrage"
wait_ready
curl -fsS "$url/api/health" | json "print(d['name'], d['version'])"

step "premier démarrage : config.json créé avec la master seule"
curl -fsS "$url/api/config" |
  json "assert [t['kind'] for t in d['tiles']] == ['master'], d"

step "interface web servie, revalidée à chaque visite"
curl -fsS "$url/" | grep -q flutter_bootstrap.js
curl -fsSI "$url/main.dart.js" | grep -qi '^cache-control: no-cache'

step "enregistrement d'une configuration (volume /data accessible en écriture)"
curl -fsS -X PUT "$url/api/config" -H 'Content-Type: application/json' \
  --data-binary @config.example.json | json "assert d['changed'], d"

step "redémarrage : la configuration enregistrée est gardée"
docker restart "$name" >/dev/null
wait_ready
curl -fsS "$url/api/config" | json "assert len(d['tiles']) == 3, d"

step "HTTPS vers GitHub (certificats de l'image)"
i=0
until curl -fsS "$url/api/state" | json "
sources = d['sources'].values()
read = [s for s in sources if s['updated_at']]
errors = [s['error']['en'] for s in sources if s['error']]
# Une réponse de GitHub, même « quota épuisé », prouve que TLS fonctionne.
quota = [e for e in errors if 'quota' in e or '403' in e]
if not (read or quota):
    raise SystemExit(1)
print(len(read), 'source(s) lue(s)', errors)"; do
  i=$((i + 1))
  [ "$i" -le 30 ] || {
    curl -fsS "$url/api/state" | json "print([s['error'] for s in d['sources'].values()])"
    exit 1
  }
  sleep 1
done

echo "== image correcte"

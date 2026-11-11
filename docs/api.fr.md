<!-- BuildBeacon — API REST (français). Version 1.1 (2026-11-11) — événement config, validation sans jeton, interface web. -->
# API REST

[English version](api.md)

Le Hub sert une API JSON, utilisée par l'interface web : lire et modifier la configuration,
lister les plugins, suivre l'état des tuiles en direct, identifier une tuile, vérifier WLED.

```
http://<adresse du hub>:8080/api
```

## Conventions

- **JSON** en entrée et en sortie (`Content-Type: application/json`).
- **Les textes destinés à l'utilisateur sont traduits** : chaque message est un objet avec
  une entrée par langue de l'interface — `{"en": "…", "fr": "…"}` — et le client choisit sa
  langue. Les libellés et descriptions des plugins suivent le même format.
- **Erreurs** : `{"error": {"en": "…", "fr": "…"}}` avec le code HTTP ci-dessous.
- **Identifiants en anglais**, comme dans `config.json` (`overall`, `dots`, `running`…).
- **Aucun secret ne sort jamais de l'API** : pour chaque secret d'un plugin, seulement s'il
  est renseigné.

| Code | Sens |
|---|---|
| 200 | OK |
| 202 | accepté (`identify`) |
| 400 | requête illisible (JSON invalide, mauvais format, valeur hors limites) |
| 401 | `BB_API_TOKEN` défini et en-tête `Authorization` absent ou faux |
| 404 | route ou tuile inconnue |
| 415 | requête d'écriture qui n'est pas en JSON |
| 422 | configuration lisible mais avec des problèmes (`issues`) |
| 500 | la configuration n'a pas pu être enregistrée |

## Sécurité

- **Les écritures (`POST`, `PUT`) doivent être en JSON.** Un site web tiers ne peut pas
  envoyer une telle requête depuis le navigateur d'une personne de votre réseau : il lui
  faudrait une autorisation CORS que le Hub ne donne jamais.
- **Jeton facultatif** : définissez `BB_API_TOKEN`, et chaque écriture devra porter
  `Authorization: Bearer <jeton>` (l'interface web le demande quand il le faut). Les lectures
  restent ouvertes sur votre réseau (elles ne contiennent aucun secret), comme
  `POST /api/config/validate`, qui ne change rien.
- **Adresse d'écoute** : toutes les interfaces par défaut (`--listen 0.0.0.0`, nécessaire
  pour joindre l'interface depuis une autre machine) ; `--listen 127.0.0.1` pour cette
  machine seulement.
- Gardez le Hub sur votre réseau local : ne l'exposez pas sur Internet.

## Routes

| Méthode et route | Rôle |
|---|---|
| `GET /api/health` | nom, versions, durée de fonctionnement, langues |
| `GET /api/config` | configuration en cours |
| `PUT /api/config` | remplacer la configuration : validée, appliquée à chaud, enregistrée |
| `POST /api/config/validate` | valider une configuration sans l'appliquer |
| `GET /api/plugins` | plugins disponibles et leurs réglages |
| `GET /api/state` | ce que montre le Hub (tuiles, zones, sources, WLED) |
| `GET /api/events` | configuration et état, en direct (Server-Sent Events) |
| `GET /api/frame` | l'image exacte envoyée aux LED |
| `POST /api/tiles/{id}/identify` | faire clignoter une tuile |
| `POST /api/wled/check` | revérifier WLED et régler sa luminosité |

### `GET /api/health`

```json
{ "name": "BuildBeacon Hub", "version": "0.1.0", "api_version": 1, "uptime_s": 42,
  "languages": ["en", "fr"] }
```

### `GET /api/config` · `PUT /api/config`

`GET` renvoie la configuration au format de `config.json`. `PUT` prend une configuration
complète :

```sh
curl -X PUT http://hub.local:8080/api/config \
     -H 'Content-Type: application/json' -d @config.json
```

| Réponse | Corps |
|---|---|
| 200 | `{"config": {…}, "changed": true}` — appliquée et enregistrée (`false` : identique, rien n'est fait) |
| 400 | `{"error": {…}}` — illisible |
| 422 | `{"issues": [{"en": "…", "fr": "…"}, …]}` — rien ne change |
| 500 | `{"error": {…}}` — enregistrement impossible, rien ne change |

Le fichier est écrit de façon atomique (fichier temporaire, puis renommage). Modifier
`config.json` à la main fonctionne toujours : le Hub le recharge dès qu'il est enregistré.

### `POST /api/config/validate`

Même corps que `PUT` ; répond `{"valid": true, "issues": []}` ou `{"valid": false,
"issues": […]}` sans rien appliquer — pratique pour valider un formulaire pendant la saisie.

### `GET /api/plugins`

```json
{ "plugins": [ {
  "type": "github",
  "label": {"en": "GitHub Actions", "fr": "GitHub Actions"},
  "description": {"en": "…", "fr": "…"},
  "settings": [ {"id": "repo", "label": {"en": "Repository", "fr": "Dépôt"},
                 "kind": "text", "required": true, "placeholder": "owner/repo", …}, … ],
  "secrets": [ {"env": "BB_GITHUB_TOKEN", "label": {…}, "required": false, "configured": true} ],
  "provides_history": true, "metrics": [], "dynamic_metrics": false } ] }
```

L'interface construit les formulaires des sources à partir de `settings`, et ne propose que
les modes d'affichage que le plugin peut alimenter (`provides_history`, `metrics`).

### `GET /api/state`

```json
{
  "generated_at": "2026-11-11T21:55:50Z",
  "led_count": 21,
  "palette": {"success": "#00FF00", "running": "#FF5000", …},
  "pulsing": ["running", "queued"],
  "tiles": [ {
    "id": "wled", "label": "WLED", "kind": "project", "chain_index": 1,
    "pos": {"q": 0, "r": 0}, "identifying": false,
    "zones": {
      "ambient": {"mode": "overall", "source": "github:{…}",
                  "leds": [{"status": "success", "intensity": 1.0, "color": "#00FF00"}, …]},
      "dots": {…} } } ],
  "sources": { "github:{…}": {
    "type": "github", "settings": {"repo": "wled/WLED", …}, "label": "github · wled/WLED · …",
    "status": "success", "history": ["success", …], "metrics": {},
    "error": null, "updated_at": "2026-11-11T21:55:46Z" } },
  "wled": { "host": "buildbeacon.local", "port": 80, "ddp_port": 4048, "brightness": 128,
            "checked_at": "…", "info": {"version": "0.15.0", "name": "WLED", "led_count": 21},
            "led_count_matches": true, "error": null }
}
```

`color` est la couleur de la palette à l'intensité de la LED, sans la pulsation :
l'interface anime elle-même les états listés dans `pulsing`.

### `GET /api/events`

Server-Sent Events, tout de suite : un événement `config` (même contenu que
`GET /api/config`), puis un événement `state` (même contenu que `/api/state`). Ensuite, à
chaque changement, au plus 4 par seconde : `config` à nouveau si la configuration a changé
(enregistrée par l'API ou modifiée à la main), puis `state`. Un commentaire toutes les 15 s
garde la connexion ouverte.

```js
const events = new EventSource("/api/events");
events.addEventListener("config", (e) => edit(JSON.parse(e.data)));
events.addEventListener("state", (e) => render(JSON.parse(e.data)));
```

Derrière un proxy inverse, désactivez la mise en tampon pour cette route (nginx :
`proxy_buffering off;`). Sinon les événements restent bloqués, et l'interface web se replie
sur une lecture de `/api/config` et `/api/state` toutes les 2 s.

### `GET /api/frame`

```json
{ "led_count": 21, "leds": "00ff0000ff00…" }
```

Trois octets (RVB, en hexadécimal) par LED, dans l'ordre de la chaîne : exactement ce qui
part vers WLED.

### `POST /api/tiles/{id}/identify`

Corps facultatif : `{"seconds": 5}` (de 1 à 60, 5 par défaut). La tuile clignote en blanc au
mur ; `identifying` passe à `true` dans l'état. Répond 202, ou 404 pour une tuile inconnue.

### `POST /api/wled/check`

Revérifie WLED par son API JSON (nombre de LED, version) et règle la luminosité de la
configuration ; répond la section `wled` de l'état.

## Options du Hub

| Option | Variable | Défaut |
|---|---|---|
| `--port <n>` | `BB_PORT` | `8080` |
| `--listen <adresse>` | `BB_LISTEN` | `0.0.0.0` (toutes les interfaces) |
| `--web <dossier>` | `BB_WEB_DIR` | aucun : la racine `/` présente seulement l'API (`mise run hub` sert `hub/ui/build/web`, compilée par `mise run ui-build`) |
| — | `BB_API_TOKEN` | aucun : les écritures ne sont pas protégées par un jeton |

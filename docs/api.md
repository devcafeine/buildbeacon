<!-- BuildBeacon — REST API (English). Version 1.1 (2026-11-11) — config event, validation without token, web interface. -->
# REST API

[Version française](api.fr.md)

The Hub serves a JSON API used by the web interface: read and change the configuration,
list the plugins, follow the state of the tiles live, identify a tile, check WLED.

```
http://<hub address>:8080/api
```

## Conventions

- **JSON** in and out (`Content-Type: application/json`).
- **Texts for the user are translated**: every message is an object with one entry per
  language of the interface — `{"en": "…", "fr": "…"}` — and the client picks its language.
  Plugin labels and descriptions use the same format.
- **Errors**: `{"error": {"en": "…", "fr": "…"}}` with the HTTP status below.
- **Identifiers in English**, like in `config.json` (`overall`, `dots`, `running`…).
- **No secret ever goes out of the API**: for each secret of a plugin, only whether it is set.

| Status | Meaning |
|---|---|
| 200 | OK |
| 202 | accepted (`identify`) |
| 400 | unreadable request (invalid JSON, wrong format, value out of range) |
| 401 | `BB_API_TOKEN` set and missing or wrong `Authorization` header |
| 404 | unknown route or tile |
| 415 | write request that is not JSON |
| 422 | readable configuration but with problems (`issues`) |
| 500 | the configuration could not be saved |

## Security

- **Writes (`POST`, `PUT`) must be JSON.** A third-party web site cannot send such a request
  from the browser of someone on your network: it would need a CORS authorization that the
  Hub never gives.
- **Optional token**: set `BB_API_TOKEN`, and every write must carry
  `Authorization: Bearer <token>` (the web interface asks for it when needed). Reads stay
  open on your network (they contain no secret), and so does `POST /api/config/validate`,
  which changes nothing.
- **Listening address**: all interfaces by default (`--listen 0.0.0.0`, needed to reach the
  interface from another machine); `--listen 127.0.0.1` for this machine only.
- Keep the Hub on your local network: do not expose it to the Internet.

## Endpoints

| Method and route | Role |
|---|---|
| `GET /api/health` | name, versions, uptime, languages |
| `GET /api/config` | current configuration |
| `PUT /api/config` | replace the configuration: validated, applied live, saved |
| `POST /api/config/validate` | validate a configuration without applying it |
| `GET /api/plugins` | available plugins and their settings |
| `GET /api/state` | what the Hub shows now (tiles, zones, sources, WLED) |
| `GET /api/events` | configuration and state, live (Server-Sent Events) |
| `GET /api/frame` | the exact frame sent to the LEDs |
| `POST /api/tiles/{id}/identify` | make a tile blink |
| `POST /api/wled/check` | check WLED again and set its brightness |

### `GET /api/health`

```json
{ "name": "BuildBeacon Hub", "version": "0.1.0", "api_version": 1, "uptime_s": 42,
  "languages": ["en", "fr"] }
```

### `GET /api/config` · `PUT /api/config`

`GET` returns the configuration in the format of `config.json`. `PUT` takes a complete
configuration:

```sh
curl -X PUT http://hub.local:8080/api/config \
     -H 'Content-Type: application/json' -d @config.json
```

| Answer | Body |
|---|---|
| 200 | `{"config": {…}, "changed": true}` — applied and saved (`false`: identical, nothing done) |
| 400 | `{"error": {…}}` — unreadable |
| 422 | `{"issues": [{"en": "…", "fr": "…"}, …]}` — nothing changes |
| 500 | `{"error": {…}}` — could not be saved, nothing changes |

The file is written atomically (temporary file, then rename). Editing `config.json` by hand
still works: the Hub reloads it as soon as it is saved.

### `POST /api/config/validate`

Same body as `PUT`; answers `{"valid": true, "issues": []}` or `{"valid": false, "issues":
[…]}` without applying anything — handy to validate a form as the user types.

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

The interface builds the source forms from `settings`, and offers only the display modes the
plugin can feed (`provides_history`, `metrics`).

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

`color` is the palette color at the intensity of the LED, without the pulse: the interface
animates the states listed in `pulsing` itself.

### `GET /api/events`

Server-Sent Events, right away: a `config` event (same content as `GET /api/config`), then
a `state` event (same content as `/api/state`). Then at every change, at most 4 per second:
`config` again if the configuration changed (saved through the API or edited by hand), then
`state`. A comment every 15 s keeps the connection open.

```js
const events = new EventSource("/api/events");
events.addEventListener("config", (e) => edit(JSON.parse(e.data)));
events.addEventListener("state", (e) => render(JSON.parse(e.data)));
```

Behind a reverse proxy, turn buffering off for this route (nginx: `proxy_buffering off;`).
Otherwise the events stay stuck, and the web interface falls back to reading `/api/config`
and `/api/state` every 2 s.

### `GET /api/frame`

```json
{ "led_count": 21, "leds": "00ff0000ff00…" }
```

Three bytes (RGB, hexadecimal) per LED, in chain order: exactly what goes to WLED.

### `POST /api/tiles/{id}/identify`

Optional body: `{"seconds": 5}` (1 to 60, 5 by default). The tile blinks white on the wall;
`identifying` becomes `true` in the state. Answers 202, 404 for an unknown tile.

### `POST /api/wled/check`

Checks WLED again through its JSON API (LED count, version) and sets the brightness of the
configuration; answers the `wled` section of the state.

## Hub options

| Option | Variable | Default |
|---|---|---|
| `--port <n>` | `BB_PORT` | `8080` |
| `--listen <address>` | `BB_LISTEN` | `0.0.0.0` (all interfaces) |
| `--web <folder>` | `BB_WEB_DIR` | none: the root `/` only presents the API (`mise run hub` serves `hub/ui/build/web`, built by `mise run ui-build`) |
| — | `BB_API_TOKEN` | none: writes are not protected by a token |

// BuildBeacon Hub — Simulateur web : la page (HTML, CSS et JavaScript intégrés).
// Version 1.4 (2026-11-11) — langue forcée par l'adresse (?lang=en ou ?lang=fr).
//
// Intégrée au code Dart pour que l'exécutable compilé se suffise à lui-même.

/// Page du simulateur, servie sur `/`. Elle lit `/layout` (disposition) et
/// reçoit les images par `/events` (Server-Sent Events).
const simulatorPage = r'''<!doctype html>
<!-- BuildBeacon Hub — WLED simulator page. Version 1.4 (2026-11-11) -->
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>BuildBeacon simulator</title>
<style>
/* The wall first, reception state right below it, the DDP frame for details. */
:root {
  --bg: #ECEFED;
  --surface: #F7F9F8;
  --fg: #192024;
  --muted: #5A656B;
  --line: #CFD6D4;
  --chip: #E1E6E4;
  --accent: #0A6B75;
  --ok: #1E9E4A;
  --warn: #C27A00;
  --bad: #C8352B;
  --wall: #15191B;
  --wall-light: #23292C;
  --wall-text: #9AA6AC;
  --tile: #2A3034;
  --tile-edge: #3B4348;
  --tile-text: #B9C2C7;
  --dot-off: #1B2023;
  --led-off: #1B2023;
  --idx: #E9EEF0;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0F1315;
    --surface: #161B1E;
    --fg: #E3E8EA;
    --muted: #97A2A8;
    --line: #283035;
    --chip: #222A2E;
    --accent: #59C2CC;
    --ok: #3CC46A;
    --warn: #E8A33A;
    --bad: #F0675C;
    --wall: #0A0D0E;
    --wall-light: #1A2023;
    --tile: #242A2E;
    --tile-edge: #353D42;
    --dot-off: #171C1F;
    --led-off: #171C1F;
    color-scheme: dark;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
  padding-block: 24px 40px;
  padding-left: max(16px, env(safe-area-inset-left, 0px));
  padding-right: max(16px, env(safe-area-inset-right, 0px));
}
.page { max-width: 1100px; margin: 0 auto; display: grid; gap: 14px; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
header { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 14px; }
h1 { font-size: 24px; line-height: 1.2; margin: 0; letter-spacing: -0.01em; }
.sub { flex-basis: 100%; color: var(--muted); margin: 0; max-width: 70ch; }
.state {
  display: inline-flex; align-items: center; gap: 7px;
  font-size: 13px; font-weight: 600;
  padding: 3px 11px; border-radius: 999px; background: var(--chip);
}
.state::before { content: ""; width: 8px; height: 8px; border-radius: 50%; background: var(--muted); }
.state[data-s="ok"]::before { background: var(--ok); }
.state[data-s="warn"]::before { background: var(--warn); }
.state[data-s="bad"]::before { background: var(--bad); }
.lang { margin-left: auto; display: inline-flex; border: 1px solid var(--line); border-radius: 999px; overflow: hidden; }
.lang button {
  font: 600 12px/1 -apple-system, "Segoe UI", system-ui, sans-serif;
  letter-spacing: 0.04em; padding: 6px 10px; border: 0; cursor: pointer;
  background: transparent; color: var(--muted);
}
.lang button[aria-pressed="true"] { background: var(--fg); color: var(--bg); }
.wall {
  background: radial-gradient(ellipse at 50% 35%, var(--wall-light), var(--wall) 75%);
  border-radius: 10px; padding: 12px; min-height: 220px;
  display: grid; place-items: center;
}
.wall svg { display: block; width: 100%; height: auto; max-height: 70vh; }
.hint { color: var(--wall-text); text-align: center; max-width: 60ch; margin: 0; font-size: 14px; }
.status {
  margin: 0; font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 13px;
  color: var(--muted); font-variant-numeric: tabular-nums; overflow-wrap: anywhere;
}
.toggles { display: flex; flex-wrap: wrap; gap: 8px 20px; font-size: 13px; color: var(--muted); }
.toggles label { display: inline-flex; gap: 6px; align-items: center; cursor: pointer; }
.toggles input { accent-color: var(--accent); }
h2 {
  font-size: 12px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase;
  color: var(--muted); margin: 8px 0 8px;
}
.chain { display: flex; flex-wrap: wrap; gap: 10px 16px; }
.group { display: grid; gap: 4px; }
.group-label { font-size: 11px; color: var(--muted); font-family: ui-monospace, Menlo, monospace; white-space: nowrap; }
.cells { display: flex; gap: 3px; }
.cell {
  display: grid; justify-items: center; gap: 2px;
  font-family: ui-monospace, Menlo, monospace; font-size: 10px; color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.cell i { width: 14px; height: 14px; border-radius: 50%; border: 1px solid var(--line); background: var(--led-off); display: block; }
footer { font-size: 13px; color: var(--muted); max-width: 80ch; display: grid; gap: 4px; }
footer p { margin: 0; }
.hex { fill: var(--tile); stroke: var(--tile-edge); stroke-width: 0.8; }
.glow { mix-blend-mode: screen; opacity: 0.75; }
.tile-label {
  fill: var(--tile-text); font-weight: 600; opacity: 0.9;
  font-family: -apple-system, "Segoe UI", system-ui, sans-serif;
  paint-order: stroke; stroke: var(--wall); stroke-width: 1.6px; stroke-opacity: 0.6; stroke-linejoin: round;
}
.logo { fill: none; stroke: var(--tile-text); stroke-width: 1; opacity: 0.6; }
.dot { fill: var(--dot-off); stroke: var(--tile-edge); stroke-width: 0.5; }
.idx {
  display: none; fill: var(--idx); font-family: ui-monospace, Menlo, monospace;
  font-size: 5.5px; font-weight: 500; paint-order: stroke; stroke: var(--wall); stroke-width: 1.6px;
}
.show-idx .idx { display: inline; }
</style>
</head>
<body>
<div class="page">
  <header>
    <h1 data-i18n="title"></h1>
    <span class="state" id="state" data-s="idle"></span>
    <div class="lang" role="group" aria-label="Language / Langue">
      <button type="button" id="lang-fr" data-lang="fr">FR</button>
      <button type="button" id="lang-en" data-lang="en">EN</button>
    </div>
    <p class="sub" data-i18n="subtitle"></p>
  </header>

  <div class="wall">
    <svg id="panel" role="img" hidden></svg>
    <p class="hint" id="hint" data-i18n="firstFrame"></p>
  </div>
  <p class="status" id="status"></p>

  <div class="toggles">
    <label for="opt-index"><input id="opt-index" type="checkbox"> <span data-i18n="optIndex"></span></label>
    <label for="opt-raw"><input id="opt-raw" type="checkbox"> <span data-i18n="optRaw"></span></label>
  </div>

  <section>
    <h2 data-i18n="ddpFrame"></h2>
    <div class="chain" id="chain"></div>
  </section>

  <footer>
    <p data-i18n="gammaNote"></p>
    <p><span data-i18n="layoutLabel"></span> <span id="layout-source"></span></p>
  </footer>
</div>

<script>
"use strict";
// ---- Texts (i18n) ---------------------------------------------------------
const STRINGS = {
  en: {
    pageTitle: "BuildBeacon simulator",
    title: "WLED simulator",
    subtitle: "Fake WLED: receives DDP frames from the Hub or the test pattern and shows the tiles as they look on the wall.",
    panel: "Hexagonal tiles and their LEDs",
    connecting: "Connecting…",
    waiting: "Waiting",
    receiving: "Receiving",
    stale: "No frames",
    unreachable: "Simulator unreachable",
    firstFrame: "Waiting for the first frame…",
    lost: "The page lost the simulator: is it still running? Retrying automatically…",
    waitingDetail: (port, hosts) => `Waiting for DDP frames on port ${port}. On the Hub or test pattern side: wled.host = ${hosts}, wled.ddp_port = ${port}.`,
    sameMachine: "same machine",
    or: " or ",
    line: (n, fps, age, from) => `${n} LEDs · ${fps} fps · last frame ${age} ago · sender ${from}`,
    staleDetail: (age) => `No frame for ${age}: a real WLED would have gone back to its own effect.`,
    optIndex: "LED indices in the chain",
    optRaw: "Raw values (no screen correction)",
    ddpFrame: "DDP frame",
    gammaNote: "Received colors are corrected (gamma 2.2) to look like LEDs, which appear brighter than a screen pixel of the same value. WLED's global brightness is not simulated.",
    layoutLabel: "Layout:",
    layoutConfig: (n) => `config.json (${n} tiles placed as on the wall).`,
    layoutDefault: "no config.json: tiles in a row, in chain order (--config option for the real layout).",
    tile: (n) => `Tile ${n}`,
    decimal: ".",
  },
  fr: {
    pageTitle: "Simulateur BuildBeacon",
    title: "Simulateur WLED",
    subtitle: "Faux WLED : reçoit les images DDP du Hub ou de la mire et montre les tuiles telles qu'au mur.",
    panel: "Tuiles hexagonales et leurs LED",
    connecting: "Connexion…",
    waiting: "En attente",
    receiving: "Reçoit",
    stale: "Plus d'image",
    unreachable: "Simulateur injoignable",
    firstFrame: "En attente de la première image…",
    lost: "La page a perdu le simulateur : est-il toujours lancé ? Nouvelle tentative automatique…",
    waitingDetail: (port, hosts) => `En attente d'images DDP sur le port ${port}. Côté Hub ou mire : wled.host = ${hosts}, wled.ddp_port = ${port}.`,
    sameMachine: "même machine",
    or: " ou ",
    line: (n, fps, age, from) => `${n} LED · ${fps} img/s · dernière image il y a ${age} · émetteur ${from}`,
    staleDetail: (age) => `Plus d'image depuis ${age} : un vrai WLED aurait repris son propre affichage.`,
    optIndex: "Index des LED dans la chaîne",
    optRaw: "Valeurs brutes (sans correction écran)",
    ddpFrame: "Trame DDP",
    gammaNote: "Les couleurs reçues sont corrigées (gamma 2,2) pour ressembler à des LED, qui paraissent plus lumineuses qu'un pixel d'écran de même valeur. La luminosité globale de WLED n'est pas simulée.",
    layoutLabel: "Disposition :",
    layoutConfig: (n) => `config.json (${n} tuiles placées comme au mur).`,
    layoutDefault: "pas de config.json : tuiles en ligne, dans l'ordre de la chaîne (option --config pour la vraie disposition).",
    tile: (n) => `Tuile ${n}`,
    decimal: ",",
  },
};

function remember(key, value) {
  try { localStorage.setItem(`bb-sim-${key}`, value); } catch (_) { /* storage unavailable */ }
}
function recall(key) {
  try { return localStorage.getItem(`bb-sim-${key}`); } catch (_) { return null; }
}

// Language: ?lang=en|fr in the address, otherwise the saved choice, otherwise the browser.
const requested = new URLSearchParams(location.search).get("lang");
let lang = (requested && STRINGS[requested] ? requested : null)
  || recall("lang")
  || ((navigator.language || "en").toLowerCase().startsWith("fr") ? "fr" : "en");
if (!STRINGS[lang]) lang = "en";
const t = () => STRINGS[lang];

// ---- Geometry ---------------------------------------------------------------
const NS = "http://www.w3.org/2000/svg";
const FLAT = 80;                       // mm between flat sides
const R = FLAT / Math.sqrt(3);         // circumradius
const ROW = (FLAT * Math.sqrt(3)) / 2; // vertical step between rows
// Position (mm) of each local LED index from the tile center.
const LOCAL = {
  project: [
    [-9, -21, "amb"], [9, -21, "amb"],
    [24, 2, "dot"], [12, 2, "dot"], [0, 2, "dot"], [-12, 2, "dot"], [-24, 2, "dot"],
    [-9, 25, "amb"], [9, 25, "amb"],
  ],
  master: [[-15, 7, "sys"], [0, 7, "sys"], [15, 7, "sys"]],
};

const $ = (id) => document.getElementById(id);
const panel = $("panel"), chain = $("chain"), hint = $("hint");
const statusEl = $("status"), stateEl = $("state");

const el = (tag, attrs = {}, parent) => {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (parent) parent.appendChild(e);
  return e;
};
const html = (tag, cls, parent, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  if (parent) parent.appendChild(e);
  return e;
};
const hexPoints = (scale) =>
  Array.from({ length: 6 }, (_, i) => {
    const a = (Math.PI / 180) * (60 * i - 90);
    return `${(R * scale * Math.cos(a)).toFixed(2)},${(R * scale * Math.sin(a)).toFixed(2)}`;
  }).join(" ");
const secs = (ms) => `${(ms / 1000).toFixed(1).replace(".", t().decimal)} s`;

// ---- State ------------------------------------------------------------------
let layout = { tiles: [], ddp_port: 4048, timeout_ms: 2500, addresses: [] };
let leds = [];
let cells = [];
let builtKey = "";
let frame = null;
let from = "";
let lastAt = 0;
let arrivals = [];
let dirty = false;
let connected = null;
let raw = recall("raw") === "1";

// ---- Layout -----------------------------------------------------------------
// Tiles to draw: those of config.json, completed with the ranks present in
// the received frame (placed on the right, in a row).
function tilesFor(ledCount) {
  const projects = Math.max(0, Math.ceil((ledCount - 3) / 9));
  const byRank = new Map(layout.tiles.map((tile) => [tile.rank, tile]));
  const maxQ = layout.tiles.reduce((m, tile) => Math.max(m, tile.q), -1);
  const baseR = layout.tiles.length ? Math.min(...layout.tiles.map((tile) => tile.r)) : 0;
  const last = Math.max(projects, ...layout.tiles.map((tile) => tile.rank));
  const tiles = [];
  let extra = 0;
  for (let rank = 0; rank <= last; rank++) {
    const known = byRank.get(rank);
    if (known) { tiles.push(known); continue; }
    tiles.push({
      rank,
      kind: rank === 0 ? "master" : "project",
      label: rank === 0 ? "Master" : t().tile(rank),
      q: maxQ + 1 + extra++,
      r: baseR,
    });
  }
  return tiles;
}

function build(tiles) {
  panel.replaceChildren();
  chain.replaceChildren();
  leds = [];
  cells = [];
  if (!tiles.length) { panel.hidden = true; hint.hidden = false; return; }
  panel.hidden = false;
  hint.hidden = true;

  const centers = tiles.map((tile) => [FLAT * (tile.q + tile.r / 2), ROW * tile.r]);
  const pad = 6;
  const xs = centers.map((c) => c[0]);
  const ys = centers.map((c) => c[1]);
  const minX = Math.min(...xs) - FLAT / 2 - pad;
  const minY = Math.min(...ys) - R - pad;
  const w = Math.max(...xs) + FLAT / 2 + pad - minX;
  const h = Math.max(...ys) + R + pad - minY;
  panel.setAttribute("viewBox", `${minX} ${minY} ${w} ${h}`);

  const defs = el("defs", {}, panel);
  const blur = el("filter", { id: "glow", x: "-60%", y: "-60%", width: "220%", height: "220%" }, defs);
  el("feGaussianBlur", { stdDeviation: "3.5" }, blur);

  tiles.forEach((tile, ti) => {
    const [cx, cy] = centers[ti];
    const kind = tile.kind === "master" ? "master" : "project";
    const base = tile.rank === 0 ? 0 : 3 + 9 * (tile.rank - 1);
    const g = el("g", { transform: `translate(${cx} ${cy})` }, panel);
    const clip = el("clipPath", { id: `clip-${tile.rank}` }, defs);
    el("polygon", { points: hexPoints(0.95) }, clip);
    el("polygon", { points: hexPoints(0.97), class: "hex" }, g);
    const glowG = el("g", { "clip-path": `url(#clip-${tile.rank})`, filter: "url(#glow)", class: "glow" }, g);

    LOCAL[kind].forEach(([x, y, zone], local) => {
      const r = zone === "dot" ? 5 : zone === "sys" ? 8.5 : 10;
      leds[base + local] = { glow: el("circle", { cx: x, cy: y, r, fill: "#000000" }, glowG), dot: null };
    });
    if (kind === "project") {
      el("text", { x: 0, y: -17, "text-anchor": "middle", "font-size": 11, class: "tile-label" }, g).textContent = tile.label;
    } else {
      el("polygon", { points: hexPoints(0.17), class: "logo", transform: "translate(0 -14)" }, g);
      el("text", { x: 0, y: 10, "text-anchor": "middle", "font-size": 8, class: "tile-label" }, g).textContent = tile.label;
    }
    LOCAL[kind].forEach(([x, y, zone], local) => {
      if (zone === "dot") leds[base + local].dot = el("circle", { cx: x, cy: y, r: 3.3, class: "dot" }, g);
      const dy = zone === "amb" && y < 0 ? -9 : 11;
      el("text", { x, y: y + dy, "text-anchor": "middle", class: "idx" }, g).textContent = base + local;
    });

    const group = html("div", "group", chain);
    const count = LOCAL[kind].length;
    html("span", "group-label", group, `${tile.label} · ${base}–${base + count - 1}`);
    const row = html("div", "cells", group);
    for (let i = base; i < base + count; i++) {
      const cell = html("span", "cell", row);
      cells[i] = html("i", null, cell);
      html("span", null, cell, i);
    }
  });
}

function ensureBuilt(ledCount) {
  const tiles = tilesFor(ledCount);
  const key = tiles.map((tile) => `${tile.rank}:${tile.q}:${tile.r}:${tile.label}`).join("|");
  if (key !== builtKey) { build(tiles); builtKey = key; dirty = true; }
}

// ---- Colors -----------------------------------------------------------------
const cache = new Map();
function screen(hex) {
  if (raw) return `#${hex}`;
  let v = cache.get(hex);
  if (v) return v;
  const n = parseInt(hex, 16);
  v = "#" + [(n >> 16) & 255, (n >> 8) & 255, n & 255]
    .map((c) => Math.round(255 * Math.pow(c / 255, 1 / 2.2)).toString(16).padStart(2, "0"))
    .join("");
  cache.set(hex, v);
  return v;
}

function draw() {
  if (!frame) return;
  const count = frame.length / 6;
  ensureBuilt(count);
  leds.forEach((led, i) => {
    if (!led) return;
    const hex = i < count ? frame.substr(i * 6, 6) : "000000";
    const on = hex !== "000000";
    const c = screen(hex);
    led.glow.setAttribute("fill", c);
    if (led.dot) led.dot.style.fill = on ? c : "";
    if (cells[i]) {
      cells[i].style.background = on ? c : "";
      cells[i].title = `LED ${i} : #${hex.toUpperCase()}`;
    }
  });
}

// ---- Reception state --------------------------------------------------------
function setState(s, text) {
  stateEl.dataset.s = s;
  stateEl.textContent = text;
}

function hosts() {
  const [loopback, ...others] = layout.addresses;
  if (!loopback) return "?";
  return [`${loopback} (${t().sameMachine})`, ...others].join(t().or);
}

function updateStatus() {
  const now = performance.now();
  arrivals = arrivals.filter((a) => now - a <= 1000);
  if (connected === null) { setState("idle", t().connecting); statusEl.textContent = ""; return; }
  if (!connected) {
    setState("bad", t().unreachable);
    statusEl.textContent = t().lost;
    return;
  }
  if (!frame) {
    setState("idle", t().waiting);
    statusEl.textContent = t().waitingDetail(layout.ddp_port, hosts());
    return;
  }
  const age = now - lastAt;
  const line = t().line(frame.length / 6, arrivals.length, secs(age), from);
  if (age > layout.timeout_ms) {
    setState("warn", t().stale);
    statusEl.textContent = `${line}. ${t().staleDetail(secs(age))}`;
  } else {
    setState("ok", t().receiving);
    statusEl.textContent = line;
  }
}

// ---- Language ---------------------------------------------------------------
function applyLanguage() {
  document.documentElement.lang = lang;
  document.title = t().pageTitle;
  panel.setAttribute("aria-label", t().panel);
  for (const node of document.querySelectorAll("[data-i18n]")) {
    node.textContent = t()[node.dataset.i18n];
  }
  for (const button of document.querySelectorAll(".lang button")) {
    button.setAttribute("aria-pressed", String(button.dataset.lang === lang));
  }
  $("layout-source").textContent = layout.tiles.length ? t().layoutConfig(layout.tiles.length) : t().layoutDefault;
  // Default tile names depend on the language.
  builtKey = "";
  if (frame) ensureBuilt(frame.length / 6);
  else if (layout.tiles.length) ensureBuilt(0);
  updateStatus();
}

for (const button of document.querySelectorAll(".lang button")) {
  button.addEventListener("click", () => {
    lang = button.dataset.lang;
    remember("lang", lang);
    applyLanguage();
  });
}

// ---- Options ----------------------------------------------------------------
const optIndex = $("opt-index");
const optRaw = $("opt-raw");
optIndex.checked = recall("index") === "1";
optRaw.checked = raw;
panel.classList.toggle("show-idx", optIndex.checked);
optIndex.addEventListener("change", () => {
  panel.classList.toggle("show-idx", optIndex.checked);
  remember("index", optIndex.checked ? "1" : "");
});
optRaw.addEventListener("change", () => {
  raw = optRaw.checked;
  remember("raw", raw ? "1" : "");
  dirty = true;
});

// ---- Start ------------------------------------------------------------------
async function start() {
  applyLanguage();
  try {
    const response = await fetch("layout");
    if (response.ok) layout = await response.json();
  } catch (_) { /* default layout */ }
  applyLanguage();

  const events = new EventSource("events");
  events.addEventListener("open", () => { connected = true; updateStatus(); });
  events.addEventListener("error", () => { connected = false; updateStatus(); });
  events.addEventListener("frame", (e) => {
    const data = JSON.parse(e.data);
    const age = data.age_ms || 0;
    frame = data.leds;
    from = data.from;
    // An old frame (page opened after the stream stopped) keeps its real age
    // and does not count in the frame rate.
    lastAt = performance.now() - age;
    if (age === 0) arrivals.push(lastAt);
    dirty = true;
    updateStatus();
  });

  const loop = () => {
    if (dirty) { dirty = false; draw(); }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  setInterval(updateStatus, 200);
}

start();
</script>
</body>
</html>
''';

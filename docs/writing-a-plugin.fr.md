<!-- BuildBeacon — écrire un plugin (français). Version 1.2 (2026-11-12) — commentaires des exemples en anglais. -->
# Écrire un plugin

[English version](writing-a-plugin.md)

Un **plugin de source** apprend à BuildBeacon à lire quelque chose de nouveau : une autre
CI, une imprimante 3D, un service web, un capteur de la maison… Ce guide déroule un plugin
complet, du modèle à la pull request. Le plugin GitHub Actions (`hub/plugins/github/`) est
un vrai exemple à lire en parallèle.

## Ce que le Hub fait pour vous

Vous écrivez seulement comment **lire** votre source. Le Hub s'occupe du reste :

- une seule connexion par source distincte, même si plusieurs tuiles la suivent ;
- le cache des états, le rendu des LED, les animations ;
- la validation des réglages saisis, et le formulaire de l'interface ;
- les secrets : lus dans l'environnement, seuls ceux que votre plugin déclare lui sont
  transmis.

Un plugin ne dépend que du **SDK des plugins** (`package:buildbeacon_plugin_sdk`). Il est
compilé dans l'image du Hub et arrive par une pull request.

> À venir : des plugins « externes » dans n'importe quel langage, grâce à une source HTTP
> JSON générique et à un webhook entrant. Ce guide traite des plugins Dart.

## Ce que fournit un plugin

Une source remplit ce qu'elle sait dans un `SourceState` :

| Champ | Sens | Modes d'affichage qu'il ouvre |
|---|---|---|
| `status` | état actuel : `success`, `warning`, `failure`, `running`, `queued`, `cancelled`, `unknown` | `overall` |
| `history` | états passés, le plus récent d'abord | `history` (les 5 derniers sur les points) |
| `metrics` | mesures nommées (`progress`, `nozzle_temp`…) | `thresholds`, `gauge` |

`running` et `queued` pulsent sur les tuiles. Les couleurs sont choisies par l'utilisateur
(palette).

## 1. Créer le plugin

```sh
mise run new-plugin octoprint
```

La commande crée `hub/plugins/octoprint/` — un plugin qui fonctionne déjà (il interroge une
URL), ses tests et un README — et l'inscrit dans le Hub (espace de travail, dépendance du
serveur, liste des plugins intégrés). Lancez `mise run check` : tout est vert d'emblée.

## 2. Le décrire

```dart
final class OctoprintPlugin extends SourcePlugin {
  const OctoprintPlugin();

  @override
  String get type => 'octoprint';            // "type" in config.json: lowercase, digits, _

  @override
  LocalizedText get label => const LocalizedText.same('OctoPrint');

  @override
  LocalizedText get description => const LocalizedText({
    'en': 'State and progress of the current print.',
    'fr': 'État et avancement de l\'impression en cours.',
  });
  // …
}
```

**Les textes affichés à l'utilisateur sont des `LocalizedText`** : l'anglais est obligatoire
(langue de repli), le français bienvenu.

- `const LocalizedText({'en': '…', 'fr': '…'})` — un libellé fixe ;
- `const LocalizedText.same('OctoPrint')` — le même texte dans toutes les langues ;
- `LocalizedText.build((l) => tr(l, en: '…$valeur', fr: '…$valeur'))` — un message qui
  contient des valeurs, construit dans la langue du lecteur.

Les identifiants (type, clés des réglages, identifiants des mesures) sont en anglais.

### Les réglages

Chaque `SettingField` devient un champ du formulaire et une clé de la source dans
`config.json` :

| Paramètre | Rôle |
|---|---|
| `id` | clé dans `config.json` (`"url"`), minuscules, chiffres, `_` ; `type` est réservé |
| `label`, `help` | libellé et aide du champ (`LocalizedText`) |
| `kind` | `text` (défaut), `integer`, `number`, `boolean`, `choice` (avec `choices`) |
| `required` | la source ne s'ouvre pas sans lui |
| `placeholder` | exemple affiché dans le champ vide |
| `pattern`, `patternHint` | expression régulière que doit respecter un texte, et le format attendu en clair |

```dart
@override
List<SettingField> get settings => const [
  SettingField(
    id: 'url',
    label: LocalizedText({'en': 'OctoPrint address', 'fr': 'Adresse d\'OctoPrint'}),
    required: true,
    placeholder: 'http://octopi.local',
    pattern: r'https?://\S+',
    patternHint: LocalizedText.same('http(s)://…'),
  ),
];
```

Le Hub refuse un réglage inconnu (une faute de frappe serait sinon ignorée sans bruit). Pour
des contrôles entre plusieurs réglages, redéfinissez `validateSettings` — elle n'est appelée
que si chaque champ est valide.

### Les secrets

Jetons et codes d'accès ne vont jamais dans `config.json` : ils viennent de variables
d'environnement préfixées `BB_`.

```dart
@override
List<SecretField> get secrets => const [
  SecretField(
    env: 'BB_OCTOPRINT_API_KEY',
    label: LocalizedText({'en': 'API key', 'fr': 'Clé d\'API'}),
    required: true,       // the Hub does not open the source without it
  ),
];
```

### Ce que vous fournissez

```dart
@override
bool get providesHistory => false;     // true if you fill `history`

@override
List<MetricInfo> get metrics => const [
  MetricInfo(id: 'progress', label: LocalizedText({'en': 'Progress', 'fr': 'Progression'}),
      unit: '%', min: 0, max: 100),
  MetricInfo(id: 'time_left', label: LocalizedText({'en': 'Time left', 'fr': 'Temps restant'}),
      unit: 'min'),
];
```

L'interface ne propose que les modes d'affichage que votre plugin peut alimenter, et le Hub
refuse les autres avec un message clair.

## 3. Lire la source

La plupart des sources s'interrogent à intervalle régulier. `pollingStream` lit tout de
suite, puis après chaque intervalle (réglé par l'utilisateur), et s'arrête quand le Hub
n'a plus besoin de la source :

```dart
@override
Stream<SourceState> connect(SourceSettings settings, PluginContext context) {
  final url = Uri.parse(settings.text('url')).resolve('/api/job');
  final apiKey = context.secret(apiKeyEnv)!; // required: checked by the Hub
  return pollingStream(context.pollInterval, (previous) async {
    final response = await context.httpClient.get(url, headers: {'X-Api-Key': apiKey});
    // … read the response, return a SourceState
  });
}
```

- **`SourceSettings`** : les réglages, déjà validés, avec des accès typés (`text`,
  `optionalText`, `integer`, `number`, `flag`…).
- **`PluginContext`** : client HTTP partagé (`httpClient`), intervalle de scrutation,
  `secret(env)`, horloge `now()` (à utiliser à la place de `DateTime.now()`, pour les tests),
  `log()` (journal technique, en anglais).
- **`previous`** : l'état précédent. Pratique avec les requêtes conditionnelles : sur une
  réponse HTTP 304, gardez `previous.history`.
- **Erreurs** : levez une `SourceException` avec un message traduit qui dit quoi corriger.
  Le panneau garde le dernier état connu et l'interface affiche le message. Toute autre
  exception devient une « erreur inattendue ».

```dart
if (response.statusCode == 403) {
  throw const SourceException(LocalizedText({
    'en': 'OctoPrint refused the API key (403): check BB_OCTOPRINT_API_KEY',
    'fr': 'OctoPrint refuse la clé d\'API (403) : vérifier BB_OCTOPRINT_API_KEY',
  }));
}
```

**Ménagez le service** : respectez ses quotas, utilisez les requêtes conditionnelles (ETag)
quand il les connaît, n'interrogez jamais plus vite que l'intervalle donné.

**Sources qui poussent leurs données** (MQTT, websocket, server-sent events) : renvoyez votre
propre `Stream` au lieu de `pollingStream`. Il doit tout libérer (connexion, minuteurs)
quand le Hub annule l'abonnement.

## 4. Le tester

Le SDK fournit des outils de test, sans réseau ni Hub :

```dart
import 'package:buildbeacon_plugin_sdk/testing.dart';

test('respecte les règles du Hub', () {
  expect(conformanceIssues(plugin), isEmpty);
});

test('l\'adresse est obligatoire', () {
  expect(settingsIssues(plugin, {}).resolveAll('fr'), ['« Adresse d\'OctoPrint » est obligatoire']);
});

test('impression à 62 %', () async {
  final state = await firstState(
    plugin,
    {'url': 'http://octopi.local'},
    context: fakeContext(
      secrets: {'BB_OCTOPRINT_API_KEY': 'test-key'},
      respond: (request) => http.Response(
        jsonEncode({'state': 'Printing', 'progress': {'completion': 62.0, 'printTimeLeft': 1800}}),
        200,
      ),
    ),
  );
  expect(state.status, Status.running);
  expect(state.metric('progress')?.value, 62);
});
```

| Outil | Rôle |
|---|---|
| `conformanceIssues(plugin)` | les règles que le Hub vérifie au chargement (identifiants, traductions anglaises, secrets…) |
| `settingsIssues(plugin, réglages)` | la validation qu'applique le Hub aux réglages (messages traduits : `resolveAll('fr')`) |
| `fakeContext(respond:, secrets:, clock:, pollInterval:)` | HTTP simulé (sans `respond`, toute requête échoue), secrets, horloge |
| `firstState` / `firstStates` | ouvre le plugin comme le Hub et renvoie le ou les premiers états |

Testez les cas de succès, les erreurs (chaque `SourceException`) et les réponses inhabituelles.
N'utilisez jamais de vrais secrets ni le vrai service dans les tests.

## 5. L'utiliser dans `config.json`

```json
"zones": {
  "ambient": { "source": { "type": "octoprint", "url": "http://octopi.local" },
               "mode": "overall" },
  "dots":    { "source": { "type": "octoprint", "url": "http://octopi.local" },
               "mode": "gauge", "options": { "metric": "progress" } }
}
```

Les deux zones utilisent la même source : le Hub n'ouvre qu'une connexion. La jauge
(`gauge`) allume les cinq points de gauche à droite, le dernier en partie ; `thresholds`
colorerait la zone selon une mesure (`"thresholds": {"warning": 240, "failure": 260}`).

Pour le voir tourner : ajoutez la source dans `data/config.json` (copié de
`config.example.json`) et lancez `mise run hub` — avec le simulateur
(`mise run simulator -- --open`) si vous n'avez pas de tuiles. Le Hub recharge le fichier
dès que vous l'enregistrez et journalise chaque changement d'état de votre source, y
compris ses messages d'erreur.

## 6. Ouvrir une pull request

- [ ] `mise run check` passe ;
- [ ] un test `conformanceIssues`, des tests pour les réglages, les cas de succès et les erreurs ;
- [ ] les textes en anglais (obligatoire) et en français (bienvenu) ;
- [ ] le README du plugin rempli : ce qu'il surveille, réglages, secrets, exemple ;
- [ ] aucun secret dans le code ni dans les tests ;
- [ ] le service ménagé (intervalle, quotas) ;
- [ ] les lignes de version mises à jour dans les fichiers touchés.

Voir aussi [CONTRIBUTING.fr.md](../CONTRIBUTING.fr.md).

## Exemple complet : OctoPrint

Le code complet, commenté en anglais, est dans la
[version anglaise de ce guide](writing-a-plugin.md#complete-example-octoprint). Les points à
retenir :

- l'adresse d'OctoPrint en réglage, la clé d'API en secret obligatoire (`BB_OCTOPRINT_API_KEY`) ;
- deux mesures : `progress` (0 – 100 %) et `time_left` (minutes) ;
- l'état d'OctoPrint traduit en `Status` : `Printing` → `running`, `Paused` → `warning`,
  `Error` → `failure`, `Cancelling` → `cancelled`, `Operational` → `success` ;
- une `SourceException` traduite pour une clé refusée (403) et pour toute autre réponse
  inattendue.

## Référence du SDK

| Élément | Rôle |
|---|---|
| `SourcePlugin` | le contrat : `type`, `label`, `description`, `settings`, `secrets`, `providesHistory`, `metrics`, `dynamicMetrics`, `validateSettings`, `connect`, `describe` |
| `SettingField`, `SettingKind` | un réglage de la source |
| `SecretField` | un secret lu dans une variable d'environnement `BB_…` |
| `MetricInfo` | une mesure que le plugin peut fournir |
| `SourceSettings` | accès typé aux réglages |
| `PluginContext` | client HTTP, intervalle de scrutation, secrets, horloge, journal |
| `SourceState`, `Metric`, `Status` | ce que renvoie le plugin |
| `SourceException` | une erreur de lecture au message traduit |
| `pollingStream` | boucle de scrutation avec gestion des erreurs |
| `LocalizedText`, `tr`, `resolveAll` | textes traduits |
| `settingsIssues`, `conformanceIssues` | les validations du Hub |
| `testing.dart` : `fakeContext`, `firstState`, `firstStates` | outils de test |

Les sources du SDK sont dans [`hub/sdk/lib/`](../hub/sdk/lib/), avec un commentaire sur
chaque élément.

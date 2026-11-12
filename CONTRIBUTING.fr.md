<!-- BuildBeacon — guide de contribution (français). Version 1.9 (2026-11-12) — ui-build sauté si à jour, lancé par mise run hub. -->
# Participer à BuildBeacon

[English version](CONTRIBUTING.md)

Merci de votre intérêt ! BuildBeacon est un jeune projet de maker : chaque contribution
compte, du signalement d'un bug à un nouveau plugin.

## Comment aider

- **Signaler un bug ou proposer une idée** : ouvrir une [issue](https://github.com/devcafeine/buildbeacon/issues).
  Pour un bug, dites ce que vous avez fait, ce que vous attendiez et ce qui s'est passé
  (journaux, `config.json` sans les secrets, version de WLED).
- **Écrire un plugin** pour afficher une nouvelle source sur les tuiles (une autre CI, une
  imprimante 3D, un service web…) : suivre [Écrire un plugin](docs/writing-a-plugin.fr.md).
- **Traduire** : les interfaces existent en anglais et en français. Corriger une traduction
  ou ajouter une langue est bienvenu (voir [Langues](#langues)).
- **Améliorer la documentation** : phrase peu claire, étape manquante, coquille.
- **Matériel** : les modèles 3D et les cartes sont dans [`hardware/`](hardware/README.fr.md).
  Vos retours de montage (photos, réglages d'impression, corrections des cartes) sont
  bienvenus dans les issues. Tout fichier matériel modifié change de numéro de version (nom
  du fichier et en-tête).

## Bien démarrer

Prérequis : [git](https://git-scm.com/) et [mise](https://mise.jdx.dev/) (il installe le SDK
Flutter/Dart exact du projet).

```sh
git clone https://github.com/<vous>/buildbeacon.git   # votre fork
cd buildbeacon
mise install
mise run get
mise run check        # doit passer avant toute pull request
```

Tâches utiles (`mise tasks` les liste toutes) :

| Tâche | Rôle |
|---|---|
| `mise run check` | format, analyse statique, tous les tests — comme la CI |
| `mise run format` | formate le code |
| `mise run test` | tests de chaque paquet |
| `mise run hub` | lance le Hub avec `data/config.json` (créé au premier démarrage, ou copie de `config.example.json`) et son interface web sur http://localhost:8080 |
| `mise run ui-build` | compile l'interface web (Flutter Web) si ses sources ont changé ; `mise run hub` la lance d'abord |
| `mise run ui-dev` | interface web avec rechargement à chaud sur http://localhost:8081, à côté de `mise run hub` |
| `mise run simulator -- --open` | faux WLED dans une page web, pour travailler sans matériel |
| `mise run test-pattern -- --host 127.0.0.1` | mire vers le simulateur |
| `mise run new-plugin <nom>` | crée un plugin à partir du modèle |
| `mise run docker-test` | construit l'image Docker et l'essaie (Docker nécessaire) |

## Règles du projet

### Langues

- **Identifiants en anglais** : code, valeurs de `config.json`, options en ligne de commande,
  noms de fichiers.
- **Commentaires du code, noms des tests et messages de commit en anglais**, pour que tout
  le monde puisse lire le code.
- **Les textes affichés à l'utilisateur sont traduits** (anglais et français) : en Dart, ce
  sont des `LocalizedText` ; l'interface web utilise des fichiers ARB
  (`hub/ui/lib/l10n/app_<langue>.arb`, générés par `mise run get`) ; la page du simulateur a
  un dictionnaire par langue. L'anglais sert de repli et il est obligatoire.
- **Les messages pour les développeurs** (conformité d'un plugin, erreurs de programmation)
  sont en anglais.

Ajouter une langue : ajouter son code à `supportedLanguages`
(`hub/sdk/lib/src/localized_text.dart`), ajouter les traductions aux `LocalizedText`, un
fichier `app_<langue>.arb` à l'interface web et au dictionnaire de la page du simulateur,
puis ouvrir une pull request — une traduction partielle
convient, l'anglais remplace ce qui manque.

### Une version sur chaque fichier

Chaque fichier commence par une ligne de version, incrémentée à chaque modification, avec
la date et une courte note. Par exemple :

```dart
// BuildBeacon Hub — GitHub Actions plugin.
// Version 1.4 (2026-11-12) — comments in English.
```

Dans les fichiers YAML, TOML ou shell : `# File version: 1.3 (…)` ; en Markdown : un
commentaire HTML en première ligne. Exception : `LICENSE`, gardé mot pour mot pour que
GitHub le reconnaisse.

### Code

- Dart idiomatique, `dart format`, aucune remarque avec `dart analyze --fatal-infos`.
- **Des tests pour chaque changement** : le comportement, pas l'implémentation. Le calcul
  des index de LED et les correspondances d'états doivent rester couverts.
- Un plugin ne dépend que du SDK des plugins (`package:buildbeacon_plugin_sdk`), jamais du
  cœur.
- Les secrets (jetons, codes d'accès) viennent de variables d'environnement `BB_…` : jamais
  dans `config.json`, jamais dans un commit. `.env` est ignoré par git.

## Pull requests

1. Créer une branche à partir de `main` dans votre fork.
2. Faire des changements petits et ciblés ; mettre à jour la documentation et les lignes de
   version des fichiers touchés.
3. Lancer `mise run check`.
4. Ouvrir la pull request et remplir la liste de vérification. La CI lance la même
   vérification.

Un mainteneur la relit, peut demander des changements, puis la fusionne. Merci de votre
bienveillance et de votre patience : c'est un projet personnel.

Chaque fusion dans `main` publie l'image Docker `ghcr.io/devcafeine/buildbeacon-hub:latest`
(workflow `publish`).

### Publier une version (mainteneurs)

1. Dans une pull request, mettre la nouvelle version dans `hub/server/lib/src/api/api.dart`
   (`hubVersion`, affichée par `/api/health`) et dans `hub/server/pubspec.yaml`.
2. Une fois fusionnée, étiqueter le commit fusionné et pousser l'étiquette :
   `git tag v0.2.0 && git push origin v0.2.0`.
3. Le workflow `publish` publie l'image en `0.2.0` et `0.2` (`latest` l'a déjà, depuis la
   fusion).

## Sécurité

Si vous trouvez une faille (par exemple, un moyen de lire un secret par l'API), n'ouvrez pas
d'issue publique : contactez le mainteneur en privé sur GitHub
([@devcafeine](https://github.com/devcafeine)).

## Licence

En contribuant, vous acceptez que vos contributions soient publiées sous la
[licence MIT](LICENSE) du projet.

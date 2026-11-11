<!-- BuildBeacon — guide de contribution (français). Version 1.1 (2026-11-11) — mise run hub. -->
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
- **Matériel** : les modèles 3D et les cartes seront publiés plus tard ; les retours sur vos
  montages sont déjà bienvenus dans les issues.

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
| `mise run hub` | lance le Hub avec `data/config.json` (copie de `config.example.json`) |
| `mise run simulator -- --open` | faux WLED dans une page web, pour travailler sans matériel |
| `mise run test-pattern -- --host 127.0.0.1` | mire vers le simulateur |
| `mise run new-plugin <nom>` | crée un plugin à partir du modèle |

## Règles du projet

### Langues

- **Identifiants en anglais** : code, valeurs de `config.json`, options en ligne de commande,
  noms de fichiers.
- **Commentaires du code et messages de commit en français**, la langue de travail du
  projet. Si le français vous est difficile, écrivez en anglais : ce sera très bien.
- **Les textes affichés à l'utilisateur sont traduits** (anglais et français) : en Dart, ce
  sont des `LocalizedText` ; les pages web ont un dictionnaire par langue. L'anglais sert de
  repli et il est obligatoire.
- **Les messages pour les développeurs** (conformité d'un plugin, erreurs de programmation)
  sont en anglais.

Ajouter une langue : ajouter son code à `supportedLanguages`
(`hub/sdk/lib/src/localized_text.dart`), ajouter les traductions aux `LocalizedText` et aux
dictionnaires des pages web, puis ouvrir une pull request — une traduction partielle
convient, l'anglais remplace ce qui manque.

### Une version sur chaque fichier

Chaque fichier commence par une ligne de version, incrémentée à chaque modification, avec
la date et une courte note. Par exemple :

```dart
// BuildBeacon Hub — Plugin GitHub Actions.
// Version 1.2 (2026-11-11) — libellés et aides traduits.
```

Dans les fichiers YAML ou TOML : `# Version du fichier : 1.3 (…)` ; en Markdown : un
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

## Sécurité

Si vous trouvez une faille (par exemple, un moyen de lire un secret par l'API), n'ouvrez pas
d'issue publique : contactez le mainteneur en privé sur GitHub
([@devcafeine](https://github.com/devcafeine)).

## Licence

En contribuant, vous acceptez que vos contributions soient publiées sous la
[licence MIT](LICENSE) du projet.

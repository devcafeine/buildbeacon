<!-- BuildBeacon — contributing guide (English). Version 1.0 (2026-11-11) -->
# Contributing to BuildBeacon

[Version française](CONTRIBUTING.fr.md)

Thank you for your interest! BuildBeacon is a young maker project: every contribution
helps, from a bug report to a new plugin.

## Ways to help

- **Report a bug or suggest an idea**: open an [issue](https://github.com/devcafeine/buildbeacon/issues).
  For a bug, say what you did, what you expected and what happened (logs, `config.json`
  without secrets, WLED version).
- **Write a plugin** to show a new source on the tiles (another CI, a 3D printer, a web
  service…): follow [Writing a plugin](docs/writing-a-plugin.md).
- **Translate**: the interfaces exist in English and French. Fixing a translation or adding
  a language is welcome (see [Languages](#languages)).
- **Improve the docs**: unclear sentence, missing step, typo.
- **Hardware**: the 3D models and boards will be published later; feedback on builds is
  already welcome in the issues.

## Getting started

Requirements: [git](https://git-scm.com/) and [mise](https://mise.jdx.dev/) (it installs the
exact Flutter/Dart SDK of the project).

```sh
git clone https://github.com/<you>/buildbeacon.git   # your fork
cd buildbeacon
mise install
mise run get
mise run check        # must pass before any pull request
```

Useful tasks (`mise tasks` lists them all):

| Task | What it does |
|---|---|
| `mise run check` | format check, static analysis, every test — the same as the CI |
| `mise run format` | format the code |
| `mise run test` | tests of every package |
| `mise run simulator -- --open` | fake WLED in a web page, to work without hardware |
| `mise run test-pattern -- --host 127.0.0.1` | test pattern towards the simulator |
| `mise run new-plugin <name>` | create a plugin from the template |

## Project rules

### Languages

- **Identifiers in English**: code, `config.json` values, command-line options, file names.
- **Code comments and commit messages in French**, the working language of the project. If
  writing French is hard for you, write in English: it will be fine.
- **Texts shown to users are translated** (English and French): in Dart, they are
  `LocalizedText` values; the web pages carry a dictionary per language. English is the
  fallback and is required.
- **Messages for developers** (plugin conformance, programming errors) are in English.

Adding a language: add its code to `supportedLanguages` (`hub/sdk/lib/src/localized_text.dart`),
add the translations to the `LocalizedText` values and to the dictionaries of the web pages,
then open a pull request — partial translations are fine, English is used for what is
missing.

### A version on every file

Every file starts with a version line, incremented on each change, with the date and a
short note. For example:

```dart
// BuildBeacon Hub — Plugin GitHub Actions.
// Version 1.2 (2026-11-11) — libellés et aides traduits.
```

In YAML or TOML files: `# Version du fichier : 1.3 (…)`; in Markdown: an HTML comment on the
first line. Exception: `LICENSE`, kept verbatim so that GitHub recognizes it.

### Code

- Idiomatic Dart, `dart format`, no warning with `dart analyze --fatal-infos`.
- **Tests for every change**: the behavior, not the implementation. LED index computations
  and state mappings must stay covered.
- A plugin depends only on the plugin SDK (`package:buildbeacon_plugin_sdk`), never on the
  core.
- Secrets (tokens, access codes) come from `BB_…` environment variables: never in
  `config.json`, never in a commit. `.env` is ignored by git.

## Pull requests

1. Create a branch from `main` in your fork.
2. Make small, focused changes; update the docs and the version lines of the files you
   touch.
3. Run `mise run check`.
4. Open the pull request and fill in the checklist. The CI runs the same check.

A maintainer reviews it, may ask for changes, then merges. Be kind and patient: this is a
side project.

## Security

If you find a vulnerability (for example, a way to read a secret through the API), do not
open a public issue: contact the maintainer privately through GitHub
([@devcafeine](https://github.com/devcafeine)).

## License

By contributing, you agree that your contributions are released under the
[MIT license](LICENSE) of the project.

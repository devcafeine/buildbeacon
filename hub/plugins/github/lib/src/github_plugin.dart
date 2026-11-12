// BuildBeacon Hub — GitHub Actions plugin.
// Version 1.3 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import 'github_runs_reader.dart';

/// GitHub Actions plugin: status and history of the latest runs of a
/// repository, a workflow or a branch.
///
/// Written only with the plugin SDK, as a community plugin would be.
final class GithubPlugin extends SourcePlugin {
  const GithubPlugin();

  static const tokenEnv = 'BB_GITHUB_TOKEN';

  @override
  String get type => 'github';

  @override
  LocalizedText get label => const LocalizedText.same('GitHub Actions');

  @override
  LocalizedText get description => const LocalizedText({
    'en':
        'Status of the latest GitHub Actions runs of a repository, '
        'a workflow or a branch.',
    'fr':
        'État des derniers runs GitHub Actions d\'un dépôt, d\'un workflow '
        'ou d\'une branche.',
  });

  @override
  List<SettingField> get settings => const [
    SettingField(
      id: 'repo',
      label: LocalizedText({'en': 'Repository', 'fr': 'Dépôt'}),
      required: true,
      placeholder: 'owner/repo',
      pattern: r'[A-Za-z0-9-]+/[A-Za-z0-9._-]+',
      patternHint: LocalizedText.same('owner/repo'),
    ),
    SettingField(
      id: 'workflow',
      label: LocalizedText.same('Workflow'),
      placeholder: 'ci.yml',
      help: LocalizedText({
        'en': 'File name or numeric id; empty = all workflows.',
        'fr':
            'Nom du fichier ou identifiant numérique ; vide = tous les '
            'workflows.',
      }),
    ),
    SettingField(
      id: 'branch',
      label: LocalizedText({'en': 'Branch', 'fr': 'Branche'}),
      placeholder: 'main',
      help: LocalizedText({
        'en': 'Empty = all branches.',
        'fr': 'Vide = toutes les branches.',
      }),
    ),
  ];

  @override
  List<SecretField> get secrets => const [
    SecretField(
      env: tokenEnv,
      label: LocalizedText({
        'en': 'GitHub token (read-only)',
        'fr': 'Jeton GitHub (lecture seule)',
      }),
      help: LocalizedText({
        'en':
            'Fine-grained token with Actions: read and Metadata: read. '
            'Without a token: public repositories only, 60 requests per hour.',
        'fr':
            'Jeton fine-grained avec Actions: read et Metadata: read. '
            'Sans jeton : dépôts publics seulement, 60 requêtes par heure.',
      }),
    ),
  ];

  @override
  bool get providesHistory => true;

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) {
    final reader = GithubRunsReader(
      repo: settings.text('repo'),
      workflow: settings.optionalText('workflow'),
      branch: settings.optionalText('branch'),
      client: context.httpClient,
      token: context.secret(tokenEnv),
      clock: context.now,
    );
    return pollingStream(context.pollInterval, reader.read);
  }
}

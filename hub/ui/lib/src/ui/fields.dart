// BuildBeacon UI — Champs de saisie liés au brouillon.
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';

/// Champ texte qui suit une valeur du brouillon : il se met à jour quand
/// elle change ailleurs (annulation, autre onglet), sans écraser la saisie
/// en cours ([same] dit si le texte saisi correspond déjà à la valeur).
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.same,
    this.onSubmitted,
    this.focusNode,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool Function(String text, String value)? same;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SyncedTextField old) {
    super.didUpdateWidget(old);
    final same = widget.same ?? _sameText;
    if (!same(_controller.text, widget.value)) {
      _controller.text = widget.value;
    }
  }

  static bool _sameText(String text, String value) =>
      text.trim() == value.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: widget.focusNode,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    keyboardType: widget.keyboardType,
    inputFormatters: widget.inputFormatters,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helper,
      helperMaxLines: 4,
      errorText: widget.error,
      errorMaxLines: 4,
      suffixText: widget.suffix,
    ),
  );
}

bool _sameNumber(String text, String value) =>
    parseNumber(text) == parseNumber(value) || text.trim() == value.trim();

/// Nombre facultatif (seuil, borne de jauge) : vide = `null`.
class OptionalNumberField extends StatefulWidget {
  const OptionalNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.helper,
    this.suffix,
  });

  final num? value;
  final ValueChanged<num?> onChanged;
  final String label;
  final String? helper;
  final String? suffix;

  @override
  State<OptionalNumberField> createState() => _OptionalNumberFieldState();
}

class _OptionalNumberFieldState extends State<OptionalNumberField> {
  bool _invalid = false;

  @override
  Widget build(BuildContext context) => SyncedTextField(
    value: widget.value == null ? '' : formatNumber(widget.value!),
    label: widget.label,
    helper: widget.helper,
    suffix: widget.suffix,
    error: _invalid ? context.l10n.numberExpected : null,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    same: _sameNumber,
    onChanged: (text) {
      final number = parseNumber(text);
      final invalid = text.trim().isNotEmpty && number == null;
      if (invalid != _invalid) setState(() => _invalid = invalid);
      if (!invalid) widget.onChanged(number);
    },
  );
}

/// Nombre entier obligatoire (port, intervalle) ; [min] – [max] vérifiés ici,
/// le Hub revérifie à l'enregistrement.
class IntField extends StatefulWidget {
  const IntField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.helper,
    this.suffix,
    this.min,
    this.max,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String label;
  final String? helper;
  final String? suffix;
  final int? min;
  final int? max;

  @override
  State<IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<IntField> {
  String? _error;

  @override
  Widget build(BuildContext context) => SyncedTextField(
    value: '${widget.value}',
    label: widget.label,
    helper: widget.helper,
    suffix: widget.suffix,
    error: _error,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    same: _sameNumber,
    onChanged: (text) {
      final l = context.l10n;
      final value = int.tryParse(text.trim());
      final error = switch (value) {
        null => l.integerExpected,
        final v when widget.min != null && v < widget.min! => l.integerAtLeast(
          widget.min!,
        ),
        final v when widget.max != null && v > widget.max! => l.integerAtMost(
          widget.max!,
        ),
        _ => null,
      };
      if (error != _error) setState(() => _error = error);
      if (error == null) widget.onChanged(value!);
    },
  );
}

/// Champ d'un réglage de plugin, choisi d'après sa description
/// ([SettingField]) ; erreurs données par les mêmes règles que le Hub.
class SettingInput extends StatelessWidget {
  const SettingInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final SettingField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = field.label.of(context) + (field.required ? ' *' : '');
    final help = field.help?.of(context);
    final error = field.validate(value).firstOrNull?.of(context);

    switch (field.kind) {
      case SettingKind.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: help == null ? null : Text(help),
          value: value == true,
          onChanged: onChanged,
        );
      case SettingKind.choice:
        final current = field.choices.contains(value) ? value as String : null;
        return DropdownButtonFormField<String?>(
          // Clé = valeur : le champ suit les changements venus d'ailleurs.
          key: ValueKey(current),
          initialValue: current,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            helperText: help,
            helperMaxLines: 4,
            errorText: error,
          ),
          items: [
            if (!field.required)
              const DropdownMenuItem(value: null, child: Text('—')),
            for (final choice in field.choices)
              DropdownMenuItem(value: choice, child: Text(choice)),
          ],
          onChanged: onChanged,
        );
      case SettingKind.text || SettingKind.integer || SettingKind.number:
        final numeric = field.kind != SettingKind.text;
        return SyncedTextField(
          value: switch (value) {
            null => '',
            final num n => formatNumber(n),
            _ => '$value',
          },
          label: label,
          hint: field.placeholder,
          helper: help,
          error: error,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          same: numeric ? _sameNumber : null,
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) return onChanged(null);
            onChanged(switch (field.kind) {
              // Texte invalide gardé tel quel : la validation le signale.
              SettingKind.integer => int.tryParse(trimmed) ?? trimmed,
              SettingKind.number => parseNumber(trimmed) ?? trimmed,
              _ => trimmed,
            });
          },
        );
    }
  }
}

/// Titre de section dans un panneau.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

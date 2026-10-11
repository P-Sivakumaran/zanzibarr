import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../metadata/metadata_service.dart';
import '../tv_focus.dart';
import 'release_search_selection.dart';

Future<ReleaseSearchSelection?> showStructuredSearchDialog(
  BuildContext context, {
  ReleaseSearchSelection? initial,
  String title = '',
}) => showDialog<ReleaseSearchSelection>(
  context: context,
  builder: (_) => _StructuredSearchDialog(initial: initial, title: title),
);

class _StructuredSearchDialog extends StatefulWidget {
  const _StructuredSearchDialog({this.initial, required this.title});
  final ReleaseSearchSelection? initial;
  final String title;
  @override
  State<_StructuredSearchDialog> createState() =>
      _StructuredSearchDialogState();
}

class _StructuredSearchDialogState extends State<_StructuredSearchDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.initial?.title ?? widget.title,
  );
  late final _imdb = TextEditingController(text: widget.initial?.imdbId ?? '');
  late final _tvdb = TextEditingController(text: widget.initial?.tvdbId ?? '');
  late final _year = TextEditingController(
    text: widget.initial?.year?.toString() ?? '',
  );
  late final _season = TextEditingController(
    text: widget.initial?.season?.toString() ?? '',
  );
  late final _episode = TextEditingController(
    text: widget.initial?.episode?.toString() ?? '',
  );
  late final _controllers = [_title, _imdb, _tvdb, _year, _season, _episode];
  late final _focus = [
    for (final controller in _controllers) dpadTraversalFocusNode(controller),
  ];
  late String _kind = widget.initial?.kind ?? 'movie';

  @override
  void dispose() {
    for (final node in _focus) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      ReleaseSearchSelection(
        title: _title.text.trim(),
        kind: _kind,
        imdbId: normalizeImdbId(_imdb.text),
        tvdbId: _kind == 'tv' && _tvdb.text.trim().isNotEmpty
            ? _tvdb.text.trim()
            : null,
        year: _kind == 'movie' ? int.tryParse(_year.text) : null,
        season: _kind == 'tv' ? int.tryParse(_season.text) : null,
        episode: _kind == 'tv' ? int.tryParse(_episode.text) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? number(String? text, {int min = 0, int max = 9999}) {
      if (text == null || text.isEmpty) return null;
      final n = int.tryParse(text);
      return n == null || n < min || n > max ? l.metadataInvalidNumber : null;
    }

    Widget field(
      int index,
      String label, {
      String? Function(String?)? validate,
      bool numeric = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focus[index],
        autofocus: index == 0,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label),
        validator: validate,
      ),
    );
    return AlertDialog(
      title: Text(l.structuredSearchTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.structuredSearchHint),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.metadataType),
                  items: [
                    DropdownMenuItem(
                      value: 'movie',
                      child: Text(l.metadataMovie),
                    ),
                    DropdownMenuItem(
                      value: 'tv',
                      child: Text(l.metadataSeries),
                    ),
                  ],
                  onChanged: (kind) => setState(() => _kind = kind!),
                ),
                field(
                  0,
                  l.metadataTitleLabel,
                  validate: (text) => (text?.trim().isEmpty ?? true)
                      ? l.metadataTitleRequired
                      : null,
                ),
                field(
                  1,
                  l.metadataImdbId,
                  validate: (text) =>
                      text == null ||
                          text.trim().isEmpty ||
                          normalizeImdbId(text) != null
                      ? null
                      : l.metadataInvalidId,
                ),
                if (_kind == 'movie')
                  field(
                    3,
                    l.metadataYear,
                    numeric: true,
                    validate: (text) => number(text, min: 1888, max: 2200),
                  ),
                if (_kind == 'tv') ...[
                  field(
                    2,
                    l.metadataTvdbId,
                    numeric: true,
                    validate: (text) =>
                        text == null ||
                            text.isEmpty ||
                            RegExp(r'^[1-9]\d{0,9}$').hasMatch(text)
                        ? null
                        : l.metadataInvalidId,
                  ),
                  field(4, l.metadataSeason, numeric: true, validate: number),
                  field(
                    5,
                    l.metadataEpisode,
                    numeric: true,
                    validate: (text) =>
                        text != null && text.isNotEmpty && _season.text.isEmpty
                        ? l.metadataEpisodeNeedsSeason
                        : number(text, min: 1),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.metadataFindReleases)),
      ],
    );
  }
}

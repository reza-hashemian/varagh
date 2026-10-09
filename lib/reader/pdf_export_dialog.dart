import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/file_dialogs.dart';
import '../data/backup.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'pdf_export.dart';

/// Asks which annotations of [book] to put onto its pages, then makes the
/// PDF and asks where to save it.
Future<void> showPdfExportDialog(BuildContext context, Book book) =>
    showDialog<void>(
      context: context,
      builder: (context) => _PdfExportDialog(book: book),
    );

class _PdfExportDialog extends StatefulWidget {
  const _PdfExportDialog({required this.book});

  final Book book;

  @override
  State<_PdfExportDialog> createState() => _PdfExportDialogState();
}

class _PdfExportDialogState extends State<_PdfExportDialog> {
  late final _library = AppScope.read(context).library;
  late final _byPart = <ExportPart, List<Annotation>>{};
  late final Set<ExportPart> _chosen;
  var _annotatedOnly = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    for (final annotation in _library.annotations(widget.book.id)) {
      final part = exportPartOf(annotation);
      if (part != null) (_byPart[part] ??= []).add(annotation);
    }
    _chosen = _byPart.keys.toSet();
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await exportAnnotatedPdf(
        _library.fileOf(widget.book).path,
        [for (final part in _chosen) ..._byPart[part]!],
        annotatedPagesOnly: _annotatedOnly,
      );
      final saved = await saveBytesAs(
        '${safeFileName(widget.book.title)}.pdf',
        bytes,
      );
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text(l.exportSaved)));
        return;
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed)));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final labels = {
      ExportPart.highlights: l.highlights,
      ExportPart.handwriting: l.handwriting,
      ExportPart.shapes: l.shapes,
      ExportPart.text: l.typedText,
      ExportPart.stickies: l.stickyNotes,
    };

    Widget check({
      required String label,
      required bool value,
      required ValueChanged<bool>? onChanged,
      String? trailing,
    }) => CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label, style: theme.textTheme.bodyMedium),
      secondary: trailing == null ? null : Text(trailing, style: soft),
      value: value,
      onChanged: onChanged == null ? null : (v) => onChanged(v ?? false),
    );

    return AlertDialog(
      title: Text(l.exportPdf),
      content: SizedBox(
        width: 340,
        child: _byPart.isEmpty
            ? Text(l.nothingToExport)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l.exportPdfHint, style: soft),
                    ),
                    for (final part in ExportPart.values)
                      check(
                        label: labels[part]!,
                        trailing: localNumber(
                          context,
                          _byPart[part]?.length ?? 0,
                        ),
                        value: _chosen.contains(part),
                        onChanged: _busy || !_byPart.containsKey(part)
                            ? null
                            : (on) => setState(
                                () => on
                                    ? _chosen.add(part)
                                    : _chosen.remove(part),
                              ),
                      ),
                    const Divider(),
                    check(
                      label: l.annotatedPagesOnly,
                      value: _annotatedOnly,
                      onChanged: _busy
                          ? null
                          : (on) => setState(() => _annotatedOnly = on),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton.icon(
          onPressed: _busy || _chosen.isEmpty ? null : _export,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 14,
                  child: CupertinoActivityIndicator(radius: 7),
                )
              : null,
          label: Text(_busy ? l.exporting : l.export),
        ),
      ],
    );
  }
}

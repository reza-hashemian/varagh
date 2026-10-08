import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'highlight_colors.dart';
import 'highlights_panel.dart';

/// Edits a highlight's color and note, or deletes it. Changes are saved as
/// they are made; [onChanged] fires after each one. Returns the color the
/// highlight ended up with, or null if it was deleted.
Future<HighlightColor?> showAnnotationDialog(
  BuildContext context, {
  required Library library,
  required Annotation annotation,
  required VoidCallback onChanged,
}) {
  return showDialog<HighlightColor>(
    context: context,
    builder: (context) => _AnnotationDialog(
      library: library,
      annotation: annotation,
      onChanged: onChanged,
    ),
  );
}

class _AnnotationDialog extends StatefulWidget {
  const _AnnotationDialog({
    required this.library,
    required this.annotation,
    required this.onChanged,
  });

  final Library library;
  final Annotation annotation;
  final VoidCallback onChanged;

  @override
  State<_AnnotationDialog> createState() => _AnnotationDialogState();
}

class _AnnotationDialogState extends State<_AnnotationDialog> {
  late final _note = TextEditingController(text: widget.annotation.note);
  late var _color = widget.annotation.color;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _setColor(HighlightColor color) {
    setState(() => _color = color);
    widget.library.updateAnnotation(widget.annotation.id, color: color);
    widget.onChanged();
  }

  void _close() {
    final note = _note.text.trim();
    if (note != widget.annotation.note) {
      widget.library.updateAnnotation(widget.annotation.id, note: note);
      widget.onChanged();
    }
    Navigator.pop(context, _color);
  }

  void _makeTask() {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final typed = _note.text.trim();
    final text =
        widget.annotation.kind == AnnotationKind.sticky && typed.isNotEmpty
        ? typed
        : annotationLabel(l, widget.annotation);
    widget.library.addTask(
      title: text.length > 120 ? '${text.substring(0, 120)}…' : text,
      sourceKind: 'annotation',
      sourceId: widget.annotation.id,
    );
    AppScope.read(context).refresh();
    _close();
    messenger.showSnackBar(SnackBar(content: Text(l.taskAdded)));
  }

  void _delete() {
    widget.library.removeAnnotation(widget.annotation.id);
    widget.onChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sticky = widget.annotation.kind == AnnotationKind.sticky;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Dismissing by tapping outside or pressing Escape keeps the note.
        if (!didPop) _close();
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: _color.swatch,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          sticky
                              ? l.stickyNote
                              : annotationLabel(l, widget.annotation),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  spacing: 10,
                  children: [
                    for (final color in HighlightColor.values)
                      Semantics(
                        button: true,
                        selected: color == _color,
                        label: color.name,
                        child: InkWell(
                          onTap: () => _setColor(color),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color.swatch,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == _color
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                TextField(
                  controller: _note,
                  minLines: 3,
                  maxLines: 8,
                  autofocus: sticky,
                  decoration: InputDecoration(
                    hintText: sticky ? l.stickyHint : l.highlightNoteHint,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: Text(l.deleteHighlight),
                    ),
                    TextButton(onPressed: _makeTask, child: Text(l.makeTask)),
                    const Spacer(),
                    FilledButton(onPressed: _close, child: Text(l.done)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

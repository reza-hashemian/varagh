import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'markdown_toolbar.dart';

const _twoPane = 620.0;

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  void _newNote({required bool twoPane}) {
    final state = AppScope.read(context);
    final note = state.library.addNote();
    state.openNoteId = note.id;
    if (!twoPane) _pushEditor(note.id);
  }

  Future<void> _pushEditor(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: NoteEditor(
            key: ValueKey(id),
            noteId: id,
            showBack: true,
            onChanged: () {},
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final notes = state.library.notes();
    // Like Notes on macOS, the newest note shows when none is picked.
    final openId = state.openNoteId ?? notes.firstOrNull?.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= _twoPane;
        final newButton = MacIconButton(
          icon: CupertinoIcons.square_pencil,
          tooltip: l.newNote,
          onPressed: () => _newNote(twoPane: twoPane),
        );

        if (notes.isEmpty) {
          return Scaffold(
            appBar: MacToolbar(title: l.notes, actions: [newButton]),
            body: EmptyState(
              icon: CupertinoIcons.square_pencil,
              title: l.noNotesTitle,
              body: l.noNotesBody,
              action: FilledButton(
                onPressed: () => _newNote(twoPane: twoPane),
                child: Text(l.newNote),
              ),
            ),
          );
        }

        final list = ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: notes.length,
          itemBuilder: (context, i) => _NoteRow(
            note: notes[i],
            selected: twoPane && notes[i].id == openId,
            onTap: () {
              state.openNoteId = notes[i].id;
              if (!twoPane) _pushEditor(notes[i].id);
            },
          ),
        );

        if (!twoPane) {
          return Scaffold(
            appBar: MacToolbar(title: l.notes, actions: [newButton]),
            body: list,
          );
        }

        final open = openId == null ? null : state.library.note(openId);
        return Row(
          children: [
            SizedBox(
              width: 260,
              child: Scaffold(
                backgroundColor: theme.colorScheme.surfaceContainerLowest,
                appBar: MacToolbar(title: l.notes, actions: [newButton]),
                body: list,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: open == null
                  ? Scaffold(
                      appBar: const MacToolbar(),
                      body: Center(
                        child: Text(
                          l.selectNote,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : NoteEditor(
                      key: ValueKey(open.id),
                      noteId: open.id,
                      onChanged: () => setState(() {}),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final title = note.title;
    return Material(
      color: selected ? MacColors.of(context).selection : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                title.isEmpty ? l.untitled : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: localDate(context, note.updatedAt)),
                    if (note.preview.isNotEmpty)
                      TextSpan(text: '   ${note.preview}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: soft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editor for one note. Saves a moment after typing stops and when it
/// closes; a note left completely empty is discarded.
class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.noteId,
    required this.onChanged,
    this.showBack = false,
  });

  final String noteId;

  /// Called after each save so a list beside the editor can refresh.
  final VoidCallback onChanged;

  final bool showBack;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  static const _saveDelay = Duration(milliseconds: 400);

  late final AppState _state;
  late final Library _library;
  late final TextEditingController _text;
  final _editorFocus = FocusNode();
  Timer? _saveTimer;
  var _dirty = false;
  var _preview = false;
  var _deleted = false;

  @override
  void initState() {
    super.initState();
    _state = AppScope.read(context);
    _library = _state.library;
    _text = TextEditingController(text: _library.note(widget.noteId)?.body);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (!_deleted) {
      if (_text.text.trim().isEmpty) {
        _library.removeNote(widget.noteId);
        // Deferred: notifying listeners isn't allowed while the tree is
        // being torn down.
        if (_state.openNoteId == widget.noteId) {
          scheduleMicrotask(() => _state.openNoteId = null);
        } else {
          scheduleMicrotask(_state.refresh);
        }
      } else if (_dirty) {
        _library.updateNote(widget.noteId, _text.text);
      }
    }
    _text.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  void _onEdited(String _) {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
  }

  void _save() {
    if (!_dirty || !mounted) return;
    _dirty = false;
    _library.updateNote(widget.noteId, _text.text);
    widget.onChanged();
  }

  void _makeTask() {
    final l = AppLocalizations.of(context);
    if (_text.text.trim().isEmpty) return;
    if (_dirty) {
      _dirty = false;
      _library.updateNote(widget.noteId, _text.text);
    }
    final title = _library.note(widget.noteId)?.title ?? '';
    _library.addTask(
      title: title.isEmpty ? l.untitled : title,
      sourceKind: 'note',
      sourceId: widget.noteId,
    );
    _state.refresh();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.taskAdded)));
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final title = _library.note(widget.noteId)?.title ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteNoteTitle),
        content: Text(l.deleteNoteBody(title.isEmpty ? l.untitled : title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _deleted = true;
    _saveTimer?.cancel();
    _library.removeNote(widget.noteId);
    _state.openNoteId = null;
    if (widget.showBack) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.9);

    return Scaffold(
      appBar: MacToolbar(
        leading: widget.showBack
            ? MacIconButton(
                icon: CupertinoIcons.chevron_back,
                tooltip: l.back,
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          MacIconButton(
            icon: CupertinoIcons.eye,
            tooltip: _preview ? l.edit : l.preview,
            active: _preview,
            onPressed: () => setState(() => _preview = !_preview),
          ),
          MacIconButton(
            icon: CupertinoIcons.checkmark_circle,
            tooltip: l.makeTask,
            onPressed: _makeTask,
          ),
          MacIconButton(
            icon: CupertinoIcons.trash,
            tooltip: l.deleteNote,
            onPressed: _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_preview)
            MarkdownToolbar(
              controller: _text,
              focusNode: _editorFocus,
              onChanged: () => _onEdited(''),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _preview
                    ? Markdown(
                        data: _text.text,
                        padding: const EdgeInsets.all(24),
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                              p: bodyStyle,
                              h1: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              h2: theme.textTheme.titleLarge,
                              h3: theme.textTheme.titleMedium,
                              blockSpacing: 14,
                            ),
                      )
                    : TextField(
                        controller: _text,
                        focusNode: _editorFocus,
                        onChanged: _onEdited,
                        autofocus: _text.text.isEmpty,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        style: bodyStyle,
                        decoration: InputDecoration(
                          hintText: l.noteHint,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.all(24),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

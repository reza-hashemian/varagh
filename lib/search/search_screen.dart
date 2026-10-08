import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../data/models.dart';
import '../home_shell.dart';
import '../l10n/app_localizations.dart';
import '../reader/highlight_colors.dart';
import '../tasks/date_picker.dart';
import '../tasks/task_dialog.dart';

/// Search across book titles, highlights and notes.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _query = TextEditingController(
    text: AppScope.read(context).searchQuery,
  );

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final query = _query.text.trim();
    final hits = state.library.search(query);

    List<Widget> group(String title, SearchKind kind) {
      final rows = hits.where((h) => h.kind == kind).toList();
      if (rows.isEmpty) return const [];
      return [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 10,
            top: 16,
            bottom: 4,
          ),
          child: Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final hit in rows) _HitRow(hit: hit),
      ];
    }

    final Widget body;
    if (query.isEmpty) {
      body = EmptyState(
        icon: CupertinoIcons.search,
        title: l.searchEmptyTitle,
        body: l.searchEmptyBody,
      );
    } else if (hits.isEmpty) {
      body = Center(
        child: Text(
          l.noResults(query),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          ...group(l.books, SearchKind.book),
          ...group(l.highlights, SearchKind.annotation),
          ...group(l.notes, SearchKind.note),
          ...group(l.tasks, SearchKind.task),
        ],
      );
    }

    return Scaffold(
      appBar: MacToolbar(
        titleWidget: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: MacSearchField(
              controller: _query,
              hint: l.searchHint,
              onChanged: (text) {
                state.searchQuery = text;
                setState(() {});
              },
            ),
          ),
        ),
      ),
      body: body,
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = AppScope.read(context);
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final Widget leading;
    final String title;
    final String subtitle;
    final VoidCallback onTap;
    switch (hit.kind) {
      case SearchKind.book:
        final book = hit.book!;
        leading = Icon(
          CupertinoIcons.book,
          size: 16,
          color: theme.colorScheme.primary,
        );
        title = book.title;
        subtitle = book.lastPage == null
            ? l.notStarted
            : l.pageOf(
                localNumber(context, book.lastPage!),
                localNumber(context, book.pageCount),
              );
        onTap = () => openBook(context, book);
      case SearchKind.annotation:
        final annotation = hit.annotation!;
        leading = Container(
          width: 4,
          height: 30,
          decoration: BoxDecoration(
            color: annotation.color.swatch,
            borderRadius: BorderRadius.circular(2),
          ),
        );
        title = annotation.text;
        subtitle = [
          hit.book!.title,
          l.pageN(localNumber(context, annotation.page)),
          if (annotation.note.isNotEmpty) annotation.note,
        ].join(' · ');
        onTap = () => openBook(context, hit.book!, annotationId: annotation.id);
      case SearchKind.note:
        final note = hit.note!;
        leading = Icon(
          CupertinoIcons.square_pencil,
          size: 16,
          color: theme.colorScheme.primary,
        );
        title = note.title.isEmpty ? l.untitled : note.title;
        subtitle = note.preview.isEmpty
            ? localDate(context, note.updatedAt)
            : note.preview;
        onTap = () => state.showNote(note.id);
      case SearchKind.task:
        final task = hit.task!;
        leading = Icon(
          task.isDone
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.circle,
          size: 16,
          color: theme.colorScheme.primary,
        );
        title = task.title;
        subtitle = task.notes.isNotEmpty
            ? task.notes
            : task.dueDay == null
            ? l.noDate
            : dueLabel(context, task.dueDay!);
        onTap = () => showTaskDialog(context, task.id);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          spacing: 10,
          children: [
            SizedBox(width: 18, child: Center(child: leading)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: soft,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

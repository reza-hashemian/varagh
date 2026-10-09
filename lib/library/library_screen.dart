import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../data/importer.dart';
import '../data/models.dart';
import '../home_shell.dart';
import '../l10n/app_localizations.dart';
import '../reader/pdf_export_dialog.dart';
import '../text/text_book.dart';
import 'backup_actions.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  var _importing = false;

  Future<void> _addBooks() async {
    final state = AppScope.read(context);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', ...textFormats.keys],
    );
    if (picked.isEmpty || !mounted) return;

    setState(() => _importing = true);
    for (final file in picked) {
      try {
        final result = await importBook(
          state.library,
          name: file.name,
          bytes: file.readAsByteStream(),
        );
        if (result.alreadyExisted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.alreadyInLibrary(result.book.title))),
          );
        }
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.importFailed(file.name))),
        );
      }
    }
    state.reloadBooks();
    if (mounted) setState(() => _importing = false);
  }

  Future<void> _confirmRemove(Book book) async {
    final state = AppScope.read(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeTitle),
        content: Text(l.removeBody(book.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    state.library.removeBook(book);
    state.reloadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final books = AppScope.of(context).books;
    final current = books.where((b) => b.lastPage != null).firstOrNull;

    final addButton = FilledButton.icon(
      onPressed: _importing ? null : _addBooks,
      icon: _importing
          ? const SizedBox.square(
              dimension: 14,
              child: CupertinoActivityIndicator(radius: 7),
            )
          : const Icon(CupertinoIcons.add, size: 15),
      label: Text(_importing ? l.importing : l.addBook),
    );

    return Scaffold(
      appBar: MacToolbar(
        title: l.library,
        actions: [if (books.isNotEmpty) addButton, const SizedBox(width: 6)],
      ),
      body: books.isEmpty
          ? EmptyState(
              icon: CupertinoIcons.book,
              title: l.emptyLibraryTitle,
              body: l.emptyLibraryBody,
              action: addButton,
            )
          : CustomScrollView(
              slivers: [
                if (current != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ContinueCard(
                        book: current,
                        onOpen: () => openBook(context, current),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l.allBooks,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          mainAxisSpacing: 22,
                          crossAxisSpacing: 22,
                          mainAxisExtent: 270,
                        ),
                    itemCount: books.length,
                    itemBuilder: (context, i) => _BookTile(
                      book: books[i],
                      onOpen: () => openBook(context, books[i]),
                      onExportPdf: () => showPdfExportDialog(context, books[i]),
                      onExport: () => exportBackupFrom(context, book: books[i]),
                      onRemove: () => _confirmRemove(books[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

String _progressLabel(BuildContext context, Book book) {
  final l = AppLocalizations.of(context);
  final page = book.lastPage;
  if (page == null) return l.notStarted;
  final at = localNumber(context, page);
  final count = localNumber(context, book.pageCount);
  return book.isPdf ? l.pageOf(at, count) : l.sectionOf(at, count);
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = AppScope.read(context).library.coverOf(book.id);
    // Books without a cover picture get a plain jacket with their title.
    final placeholder = Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              book.title,
              maxLines: 5,
              overflow: TextOverflow.fade,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            book.format.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 360,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.book, required this.onOpen});

  final Book book;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = book.progress ?? 0;
    return Material(
      color: MacColors.of(context).group,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              SizedBox(width: 64, height: 90, child: _Cover(book: book)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      l.continueReading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          '${_progressLabel(context, book)} · '
                          '${localPercent(context, progress)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.onOpen,
    required this.onExportPdf,
    required this.onExport,
    required this.onRemove,
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onExportPdf;
  final VoidCallback onExport;
  final VoidCallback onRemove;

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final l = AppLocalizations.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        if (book.isPdf) PopupMenuItem(value: 'pdf', child: Text(l.exportPdf)),
        PopupMenuItem(value: 'export', child: Text(l.exportBook)),
        PopupMenuItem(value: 'remove', child: Text(l.remove)),
      ],
    );
    switch (choice) {
      case 'pdf':
        onExportPdf();
      case 'export':
        onExport();
      case 'remove':
        onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onSecondaryTapUp: (d) => _showMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showMenu(context, d.globalPosition),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Expanded(child: _Cover(book: book)),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            LinearProgressIndicator(
              value: book.progress ?? 0,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
            Text(
              _progressLabel(context, book),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

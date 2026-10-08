import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'page_editor.dart';
import 'page_surface.dart';

const _twoPane = 640.0;

/// Notebooks and their pages. A page opens in the editor for writing,
/// typing and drawing.
class NotebooksScreen extends StatefulWidget {
  const NotebooksScreen({super.key});

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  late final AppState _state = AppScope.read(context);
  late final Library _library = _state.library;
  late String? _openId = _library.setting('notebooks.open');

  void _open(String? id) {
    setState(() => _openId = id);
    _library.setSetting('notebooks.open', id);
  }

  Future<String?> _askName(String title, {String initial = ''}) {
    final l = AppLocalizations.of(context);
    final field = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 280,
          child: TextField(
            controller: field,
            autofocus: true,
            decoration: InputDecoration(hintText: l.notebookName),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: Text(initial.isEmpty ? l.create : l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _newNotebook() async {
    final l = AppLocalizations.of(context);
    final name = await _askName(l.newNotebook);
    if (name == null || name.isEmpty) return;
    final notebook = _library.addNotebook(name);
    _library.addPage(notebook.id);
    _open(notebook.id);
    _state.refresh();
  }

  Future<void> _rename(Notebook notebook) async {
    final l = AppLocalizations.of(context);
    final name = await _askName(l.rename, initial: notebook.name);
    if (name == null || name.isEmpty) return;
    _library.renameNotebook(notebook.id, name);
    _state.refresh();
  }

  Future<void> _delete(Notebook notebook) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteNotebook),
        content: Text(l.deleteNotebookBody(notebook.name)),
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
    _library.removeNotebook(notebook.id);
    _open(null);
    _state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Subscribes to refreshes after a page was edited.
    AppScope.of(context);

    final notebooks = _library.notebooks();
    final open =
        notebooks.where((n) => n.id == _openId).firstOrNull ??
        notebooks.firstOrNull;
    final newButton = MacIconButton(
      icon: CupertinoIcons.add,
      tooltip: l.newNotebook,
      onPressed: _newNotebook,
    );

    if (notebooks.isEmpty) {
      return Scaffold(
        appBar: MacToolbar(title: l.notebooks, actions: [newButton]),
        body: EmptyState(
          icon: CupertinoIcons.book,
          title: l.noNotebooksTitle,
          body: l.noNotebooksBody,
          action: FilledButton(
            onPressed: _newNotebook,
            child: Text(l.newNotebook),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= _twoPane;
        final pages = open == null
            ? const <NotebookPage>[]
            : _library.pages(open.id);

        final main = Scaffold(
          appBar: MacToolbar(
            title: twoPane ? open?.name : null,
            titleWidget: twoPane || open == null
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MacPopupButton<String>(
                      value: open.id,
                      items: {for (final n in notebooks) n.id: n.name},
                      onChanged: _open,
                    ),
                  ),
            actions: [
              if (open != null)
                PopupMenuButton<String>(
                  tooltip: open.name,
                  icon: const Icon(CupertinoIcons.ellipsis_circle),
                  onSelected: (choice) =>
                      choice == 'rename' ? _rename(open) : _delete(open),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      height: 30,
                      child: Text(l.rename),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 30,
                      child: Text(l.deleteNotebook),
                    ),
                  ],
                ),
              if (!twoPane) newButton,
            ],
          ),
          body: open == null
              ? Center(child: Text(l.selectNotebook))
              : GridView(
                  padding: const EdgeInsets.all(22),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 22,
                    childAspectRatio: 595 / 900,
                  ),
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      _PageTile(
                        page: pages[i],
                        label: localNumber(context, i + 1),
                        onOpen: () => openNotebookPage(context, pages[i].id),
                      ),
                    _NewPageTile(
                      label: l.newPage,
                      onTap: () {
                        final page = _library.addPage(
                          open.id,
                          paper: pages.lastOrNull?.paper ?? PaperStyle.blank,
                        );
                        _state.refresh();
                        openNotebookPage(context, page.id);
                      },
                    ),
                  ],
                ),
        );
        if (!twoPane) return main;

        return Row(
          children: [
            SizedBox(
              width: 230,
              child: Scaffold(
                backgroundColor: theme.colorScheme.surfaceContainerLowest,
                appBar: MacToolbar(title: l.notebooks, actions: [newButton]),
                body: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final notebook in notebooks)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Material(
                          color: notebook.id == open?.id
                              ? MacColors.of(context).selection
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            onTap: () => _open(notebook.id),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                spacing: 8,
                                children: [
                                  Icon(
                                    notebook.bookId == null
                                        ? CupertinoIcons.book
                                        : CupertinoIcons.doc_append,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  Expanded(
                                    child: Text(
                                      notebook.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    localNumber(context, notebook.pageCount),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: main),
          ],
        );
      },
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.page,
    required this.label,
    required this.onOpen,
  });

  final NotebookPage page;
  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      spacing: 6,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: notebookPageSize.aspectRatio,
            child: Material(
              elevation: 2,
              shadowColor: Colors.black38,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(3),
              child: InkWell(
                onTap: onOpen,
                child: CustomPaint(
                  painter: PagePainter(paper: page.paper, marks: page.marks),
                ),
              ),
            ),
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NewPageTile extends StatelessWidget {
  const _NewPageTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      spacing: 6,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: notebookPageSize.aspectRatio,
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Icon(
                  CupertinoIcons.add,
                  size: 26,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

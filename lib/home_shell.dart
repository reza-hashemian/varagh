import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'data/models.dart';
import 'l10n/app_localizations.dart';
import 'library/library_screen.dart';
import 'notebook/notebooks_screen.dart';
import 'notebook/page_editor.dart';
import 'notes/notes_screen.dart';
import 'reader/reader_screen.dart';
import 'search/search_screen.dart';
import 'settings/settings_screen.dart';
import 'tasks/tasks_screen.dart';
import 'text/text_reader_screen.dart';

/// Opens [book] in the reader and remembers it as the open session.
/// [annotationId] scrolls to that highlight once the book is ready.
Future<void> openBook(
  BuildContext context,
  Book book, {
  String? annotationId,
}) async {
  final state = AppScope.read(context);
  state.sessionBookId = book.id;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => book.isPdf
          ? ReaderScreen(book: book, annotationId: annotationId)
          : TextReaderScreen(book: book),
    ),
  );
  state.sessionBookId = null;
  state.reloadBooks();
}

const _wideLayout = 760.0;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    // Reopen the book that was on screen when the app last closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      final id = state.sessionBookId;
      if (id == null) {
        // No book was open; perhaps a notebook page was.
        final pageId = state.library.setting('session.page');
        if (pageId != null && state.library.page(pageId) != null) {
          openNotebookPage(context, pageId);
        }
        return;
      }
      final book = state.library.book(id);
      if (book == null) {
        state.sessionBookId = null;
        return;
      }
      openBook(context, book);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppScope.of(context);
    final sections = <AppTab, (IconData, String)>{
      AppTab.library: (CupertinoIcons.book, l.library),
      AppTab.notes: (CupertinoIcons.square_pencil, l.notes),
      AppTab.notebooks: (CupertinoIcons.pencil_outline, l.notebooks),
      AppTab.tasks: (CupertinoIcons.checkmark_circle, l.tasks),
      AppTab.search: (CupertinoIcons.search, l.search),
      AppTab.settings: (CupertinoIcons.gear_alt, l.settings),
    };
    // Only the section on screen is built. Kept alive, the hidden ones
    // would each reload their lists on every change anywhere in the app.
    final body = KeyedSubtree(
      key: ValueKey(state.tab),
      child: switch (state.tab) {
        AppTab.library => const LibraryScreen(),
        AppTab.notes => const NotesScreen(),
        AppTab.notebooks => const NotebooksScreen(),
        AppTab.tasks => const TasksScreen(),
        AppTab.search => const SearchScreen(),
        AppTab.settings => const SettingsScreen(),
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideLayout) {
          return Scaffold(
            body: body,
            bottomNavigationBar: CupertinoTabBar(
              currentIndex: state.tab.index,
              onTap: (i) => state.tab = AppTab.values[i],
              backgroundColor: MacColors.of(context).toolbar,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant,
              items: [
                for (final (icon, label) in sections.values)
                  BottomNavigationBarItem(icon: Icon(icon), label: label),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              _Sidebar(sections: sections),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.sections});

  final Map<AppTab, (IconData, String)> sections;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final recent = state.books.where((b) => b.lastPage != null).take(5);

    Widget header(String text) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 10, top: 18, bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    Widget section(AppTab tab, {int? count}) => _SidebarItem(
      icon: sections[tab]!.$1,
      label: sections[tab]!.$2,
      count: count,
      selected: state.tab == tab,
      onTap: () => state.tab = tab,
    );

    return Container(
      width: 216,
      color: MacColors.of(context).sidebar,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header(l.appName),
              section(AppTab.library),
              section(AppTab.notes),
              section(AppTab.notebooks),
              section(AppTab.tasks, count: state.library.dueTaskCount(today)),
              section(AppTab.search),
              if (recent.isNotEmpty) header(l.recent),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final book in recent)
                      _SidebarItem(
                        icon: CupertinoIcons.doc_text,
                        label: book.title,
                        selected: false,
                        onTap: () => openBook(context, book),
                      ),
                  ],
                ),
              ),
              section(AppTab.settings),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shown at the end of the row when above zero.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? MacColors.of(context).selection : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              spacing: 8,
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (count != null && count! > 0)
                  Text(
                    localNumber(context, count!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

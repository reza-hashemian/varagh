import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../core/windows.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../text/text_reader_screen.dart';
import 'reader_screen.dart';
import 'scroll_link.dart';

/// Most books a desk holds side by side.
const _maxPanes = 3;

/// Narrowest a pane may get, by dragging or by adding a book beside it.
const _minPane = 320.0;

/// Width of the grip between two panes.
const _gripWidth = 7.0;

class _Pane {
  _Pane(this.book, this.share);

  final Book book;

  /// Part of the desk's width this pane takes, relative to the others.
  double share;

  final key = UniqueKey();
}

/// Books read side by side in one window, each in its own reader, with
/// grips between them to share out the width. A wide monitor fits two or
/// three; on a narrow screen a desk is just the one book.
class ReaderDesk extends StatefulWidget {
  const ReaderDesk({super.key, required this.books, this.annotationId});

  final List<Book> books;

  /// Highlight in the first book to scroll to once it has loaded.
  final String? annotationId;

  @override
  State<ReaderDesk> createState() => _ReaderDeskState();
}

class _ReaderDeskState extends State<ReaderDesk> {
  late final AppState _state = AppScope.read(context);
  late final _panes = [for (final book in widget.books) _Pane(book, 1)];
  final _link = ScrollLink();

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// Saves which books are open, so launch can lay the desk out again.
  void _remember() =>
      _state.sessionBookIds = [for (final pane in _panes) pane.book.id];

  void _close(_Pane pane) {
    if (_panes.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _panes.remove(pane));
    // Left alone, a book has nothing to scroll with.
    if (_panes.length == 1 && _link.isOn) _link.toggle();
    _remember();
  }

  Future<void> _openBeside(_Pane pane) async {
    final book = await pickBook(context);
    if (book == null || !mounted) return;
    setState(() {
      // The new book takes half of the pane it opens beside.
      pane.share /= 2;
      _panes.insert(_panes.indexOf(pane) + 1, _Pane(book, pane.share));
    });
    _remember();
  }

  /// Opens the book in a window of its own, which can go on another
  /// monitor, and takes it off this desk.
  Future<void> _moveToWindow(_Pane pane) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).newWindowFailed;
    if (!await openNewWindow(bookId: pane.book.id)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    if (mounted) _close(pane);
  }

  /// Moves the grip after pane [index] by [dx] pixels of [usable] width.
  void _resize(int index, double dx, double usable) {
    // In a right-to-left layout the first pane is on the right.
    if (Directionality.of(context) == TextDirection.rtl) dx = -dx;
    final a = _panes[index], b = _panes[index + 1];
    final total = _panes.fold(0.0, (sum, pane) => sum + pane.share);
    final least = _minPane / usable * total;
    final pair = a.share + b.share;
    if (pair < 2 * least) return;
    final share = (a.share + dx / usable * total).clamp(least, pair - least);
    setState(() {
      a.share = share;
      b.share = pair - share;
    });
  }

  void _evenOut() => setState(() {
    for (final pane in _panes) {
      pane.share = 1;
    }
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.maxWidth - _gripWidth * (_panes.length - 1);
        final total = _panes.fold(0.0, (sum, pane) => sum + pane.share);
        final roomForMore =
            _panes.length < _maxPanes &&
            constraints.maxWidth / (_panes.length + 1) >= _minPane;

        Widget reader(_Pane pane, double width) {
          final onClose = _panes.length > 1 ? () => _close(pane) : null;
          final onOpenBeside = roomForMore ? () => _openBeside(pane) : null;
          final onNewWindow = canOpenWindows ? () => _moveToWindow(pane) : null;
          final link = _panes.length > 1 ? _link : null;
          return SizedBox(
            width: width,
            // Each reader lays itself out for the width of its pane, as
            // it would for a window that size.
            child: MediaQuery(
              data: media.copyWith(size: Size(width, constraints.maxHeight)),
              child: KeyedSubtree(
                key: pane.key,
                child: pane.book.isPdf
                    ? ReaderScreen(
                        book: pane.book,
                        annotationId: pane == _panes.first
                            ? widget.annotationId
                            : null,
                        onClose: onClose,
                        onOpenBeside: onOpenBeside,
                        onNewWindow: onNewWindow,
                        link: link,
                      )
                    : TextReaderScreen(
                        book: pane.book,
                        onClose: onClose,
                        onOpenBeside: onOpenBeside,
                        onNewWindow: onNewWindow,
                        link: link,
                      ),
              ),
            ),
          );
        }

        return Row(
          children: [
            for (final (i, pane) in _panes.indexed) ...[
              if (i > 0) _grip(i - 1, usable),
              reader(pane, usable * pane.share / total),
            ],
          ],
        );
      },
    );
  }

  Widget _grip(int index, double usable) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) =>
          _resize(index, details.delta.dx, usable),
      onDoubleTap: _evenOut,
      child: Container(
        width: _gripWidth,
        color: MacColors.of(context).toolbar,
        child: const VerticalDivider(width: _gripWidth),
      ),
    ),
  );
}

/// Asks which book of the library to open. Returns null if cancelled.
Future<Book?> pickBook(BuildContext context) => showDialog<Book>(
  context: context,
  builder: (_) => _BookPicker(books: AppScope.read(context).books),
);

class _BookPicker extends StatefulWidget {
  const _BookPicker({required this.books});

  final List<Book> books;

  @override
  State<_BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<_BookPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wanted = normalizeForSearch(_query.text.trim());
    final shown = [
      for (final book in widget.books)
        if (normalizeForSearch(book.title).contains(wanted)) book,
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 540),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Text(l.openBeside, style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: MacSearchField(
                controller: _query,
                hint: l.findBookHint,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (shown.isNotEmpty) Navigator.pop(context, shown.first);
                },
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                itemCount: shown.length,
                itemBuilder: (context, i) => InkWell(
                  onTap: () => Navigator.pop(context, shown[i]),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Icon(
                          CupertinoIcons.doc_text,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            shown[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}

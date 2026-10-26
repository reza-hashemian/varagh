import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_state.dart';
import '../core/auto_hide_bars.dart';
import '../core/links.dart';
import '../core/mac_widgets.dart';
import '../core/shortcuts.dart';
import '../core/theme.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../draw/draw_tools.dart';
import '../draw/mark.dart';
import '../draw/mark_painter.dart';
import '../notebook/page_editor.dart';
import '../translate/translation_dialog.dart';
import 'annotation_dialog.dart';
import 'highlight_colors.dart';
import 'highlights_panel.dart';
import 'page_tint.dart';
import 'pdf_export_dialog.dart';
import 'pdf_links.dart';
import 'scroll_link.dart';
import 'sticky_painter.dart';
import 'tint_sheet.dart';

const _panelLayout = 820.0;

/// Width the toolbar needs for its title and back button, and for each
/// button. Where there isn't room for them all, as on a phone held upright
/// or a narrow pane, it keeps its main buttons and puts the rest in a menu.
const _toolbarTitle = 200.0;
const _toolbarButton = 50.0;

/// Backdrop behind the pages under a paper preset, before the tint is applied.
const _tintedBackdrop = Color(0xFFE2E2E2);

/// Size of an attached-page icon in PDF points, so it keeps its size
/// relative to the page at any zoom.
const _pageIcon = Size(20, 26);

/// How near, in PDF points, a tap or the eraser must be to pick a drawing.
const _pickReach = 5.0;

/// Something the reader's toolbar offers, as a button or a menu entry.
/// [hint] is the tooltip while it is disabled, saying what it waits for.
class _ToolbarAction {
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.hint,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final bool active;
  final VoidCallback? onPressed;
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.book,
    this.annotationId,
    this.onClose,
    this.onOpenBeside,
    this.onNewWindow,
    this.link,
  });

  final Book book;

  /// Highlight to scroll to once the book has loaded.
  final String? annotationId;

  /// Set when the reader is one of several on a desk: closes just this
  /// one, in place of going back.
  final VoidCallback? onClose;

  /// Opens another book beside this one; null when there is no room.
  final VoidCallback? onOpenBeside;

  /// Moves the book to a window of its own; null where there are none.
  final VoidCallback? onNewWindow;

  /// Scrolls this book together with the others on its desk when on;
  /// null when it is alone.
  final ScrollLink? link;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

/// Height of the page slider bar at the foot of a book, less its border.
const _pageBarHeight = 38.0;

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver
    implements LinkedReader {
  static const _saveDelay = Duration(milliseconds: 500);

  final _controller = PdfViewerController();
  final _findText = TextEditingController();
  final _findFocus = FocusNode();
  late final Library _library;
  late final AppState _appState = AppScope.read(context);
  late final String _path;
  late final bool _fileExists;

  // The viewer reloads the document whenever this object changes, so it is
  // created once and kept.
  late final _selectionParams = PdfTextSelectionParams(
    onTextSelectionChange: _onSelectionChanged,
  );

  /// Position saved by an earlier session, applied once the viewer is ready.
  ReadingState? _restore;
  late ReadingState _state;
  var _ready = false;
  var _pageCount = 0;
  Timer? _saveTimer;
  double? _dragPage;

  var _annotations = <Annotation>[];
  var _byPage = <int, List<Annotation>>{};
  PdfTextSelection? _selection;
  var _hasSelection = false;
  late HighlightColor _color;
  late bool _showPanel;

  /// A newer position from another device, offered once when the book opens.
  ({ReadingState state, String device})? _elsewhere;

  /// What is being drawn right now, in PDF space, and the page it is on.
  int? _livePage;
  Mark? _live;
  StrokeSampler? _sampler;
  Offset? _downAt;
  var _dragged = false;

  final _stickyHeights = <String, (String, double)>{};

  /// Sticky note or attached page being dragged: its id and page, where
  /// on it the pointer took hold, and where it is now (null until moved).
  String? _moveId;
  int? _movePage;
  var _moveGrip = Offset.zero;
  List<double>? _movePlace;

  /// Whether the drawing tools are out; remembered between sessions.
  late var _draw = _library.setting('reader.draw') == '1';
  late final DrawSettings _tools = DrawSettings(_library);

  /// Drawings added (or erased) this session, newest last, for undo.
  final _undo = <({String id, bool added})>[];

  /// Hides the toolbar, page bar and side panel.
  var _focus = false;

  /// Whether the bars slide away while the mouse rests; follows the
  /// setting, which a shortcut in any book can flip.
  late var _autoHide = _appState.autoHideBars;

  /// The paper the page had before the dark-page shortcut, to go back to.
  PagePaper? _paperBeforeDark;

  /// Keeps the viewer when the bars around it are laid out another way,
  /// so it isn't loaded again.
  final _viewerKey = GlobalKey();

  /// Where the last press on the page was, in viewer coordinates.
  Offset? _lastDown;

  PdfTextSearcher? _searcher;
  var _finding = false;

  /// Set while the view is being moved to follow a linked book, so the
  /// move isn't passed back.
  var _following = false;

  @override
  void initState() {
    super.initState();
    _library = AppScope.read(context).library;
    final file = _library.fileOf(widget.book);
    _path = file.path;
    _fileExists = file.existsSync();
    _restore = _library.readingState(widget.book.id);
    if (widget.annotationId == null) {
      _elsewhere = _library.newerPositionElsewhere(widget.book.id);
    }
    _state = _restore ?? const ReadingState(page: 1);
    _pageCount = widget.book.pageCount;
    _color =
        HighlightColor.values.asNameMap()[_library.setting(
          'reader.highlightColor',
        )] ??
        HighlightColor.yellow;
    _showPanel = _library.setting('reader.panel') == '1';
    _loadAnnotations();
    WidgetsBinding.instance.addObserver(this);
    _appState.addListener(_onAppChanged);
    _joinLink(widget.link);
  }

  void _onAppChanged() {
    if (_appState.autoHideBars != _autoHide && mounted) {
      setState(() => _autoHide = _appState.autoHideBars);
    }
  }

  void _toggleAutoHide() {
    final l = AppLocalizations.of(context);
    _appState.autoHideBars = !_appState.autoHideBars;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_appState.autoHideBars ? l.autoHideOn : l.autoHideOff),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  void didUpdateWidget(ReaderScreen old) {
    super.didUpdateWidget(old);
    if (old.link == widget.link) return;
    _leaveLink(old.link);
    _joinLink(widget.link);
  }

  void _joinLink(ScrollLink? link) {
    link?.join(this);
    link?.addListener(_onLinkChanged);
  }

  void _leaveLink(ScrollLink? link) {
    link?.leave(this);
    link?.removeListener(_onLinkChanged);
  }

  void _onLinkChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.removeListener(_onAppChanged);
    _leaveLink(widget.link);
    _controller.removeListener(_onViewChanged);
    _searcher?.removeListener(_onSearchChanged);
    _searcher?.dispose();
    _findText.dispose();
    _findFocus.dispose();
    _tools.dispose();
    _flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flush();
  }

  // Position

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    _pageCount = document.pages.length;
    _library.markOpened(widget.book.id, pageCount: _pageCount);

    // The viewer is rebuilt when something above it in the tree changes
    // shape; it then comes back where the reader was, not where the book
    // was opened.
    if (_ready) {
      _jumpTo(_state);
      return;
    }

    final target = widget.annotationId == null
        ? null
        : _library.annotation(widget.annotationId!);
    final saved = _restore;
    // The saved position goes first even when a highlight is the target:
    // it brings back the zoom the book was last read at.
    if (saved != null) _jumpTo(saved);
    if (target != null) _goToAnnotation(target, animate: false);

    _ready = true;
    _searcher = PdfTextSearcher(controller)..addListener(_onSearchChanged);
    controller.addListener(_onViewChanged);
    // Record the opening position too, so a book that was only looked at
    // still counts as started.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onViewChanged());
    if (mounted) setState(() {});
  }

  /// Shows the spot [position] describes, at its zoom.
  void _jumpTo(ReadingState position) {
    final layouts = _controller.layout.pageLayouts;
    final rect = layouts[(position.page - 1).clamp(0, layouts.length - 1)];
    final center =
        rect.topLeft +
        Offset(rect.width * position.fx, rect.height * position.fy);
    final zoom = (position.zoomRel * _controller.coverScale).clamp(
      _controller.minScale,
      _controller.maxScale,
    );
    // Land on whole device pixels; a fractional offset blurs the page.
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final matrix = _controller.calcMatrixFor(center, zoom: zoom);
    final shift = matrix.getTranslation();
    matrix.setTranslationRaw(
      (shift.x * ratio).roundToDouble() / ratio,
      (shift.y * ratio).roundToDouble() / ratio,
      0,
    );
    _controller.goTo(matrix, duration: Duration.zero);
  }

  Widget _continueBar(AppLocalizations l, ThemeData theme) {
    final offer = _elsewhere!;
    final page = localNumber(context, offer.state.page);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      height: 40,
      color: theme.colorScheme.primaryContainer,
      child: Row(
        spacing: 6,
        children: [
          Expanded(
            child: Text(
              offer.device.isEmpty
                  ? l.continueFromUnknown(page)
                  : l.continueFrom(page, offer.device),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () {
              _jumpTo(offer.state);
              setState(() => _elsewhere = null);
            },
            child: Text(l.go),
          ),
          MacIconButton(
            icon: CupertinoIcons.xmark,
            tooltip: l.dismiss,
            onPressed: () => setState(() => _elsewhere = null),
          ),
        ],
      ),
    );
  }

  @override
  double? get linkedPosition {
    if (!_ready || !_controller.isReady) return null;
    final layouts = _controller.layout.pageLayouts;
    final y = _controller.centerPosition.dy;
    for (final (i, rect) in layouts.indexed) {
      // A center in the gap above a page counts as that page's top.
      if (y < rect.bottom) {
        return i + ((y - rect.top) / rect.height).clamp(0.0, 1.0);
      }
    }
    return layouts.length.toDouble();
  }

  @override
  double follow(double position) {
    if (!_ready || !_controller.isReady) return position;
    final count = _controller.layout.pageLayouts.length;
    final at = position.clamp(0.0, count.toDouble());
    final index = at.floor().clamp(0, count - 1);
    _following = true;
    try {
      _jumpTo(_state.copyWith(page: index + 1, fy: at - index));
    } finally {
      _following = false;
    }
    return linkedPosition ?? at;
  }

  void _onViewChanged() {
    if (!_ready || !_controller.isReady) return;
    if (!_following) {
      final position = linkedPosition;
      if (position != null) widget.link?.moved(this, position);
    }
    final page = _controller.pageNumber;
    if (page == null) return;
    final layouts = _controller.layout.pageLayouts;
    if (page < 1 || page > layouts.length) return;

    final rect = layouts[page - 1];
    final center = _controller.centerPosition;
    final pageChanged = page != _state.page;
    _state = _state.copyWith(
      page: page,
      fx: ((center.dx - rect.left) / rect.width).clamp(0.0, 1.0),
      fy: ((center.dy - rect.top) / rect.height).clamp(0.0, 1.0),
      zoomRel: _controller.currentZoom / _controller.coverScale,
    );
    _scheduleSave();
    if (pageChanged && mounted) setState(() {});
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_ready) _library.saveReadingState(widget.book.id, _state);
  }

  /// Resolution of the whole-page preview images, as a scale over PDF points.
  ///
  /// The viewer draws a page in two layers: a cached preview of the whole
  /// page, and on top a render of just the visible area at exact screen
  /// resolution, made only when the preview is coarser than the screen.
  /// Its default preview is 200 dpi, which at ordinary zoom is finer than
  /// the screen, so the exact layer never appears and the GPU shrinks the
  /// preview, blurring text. Keeping the preview one step below what is
  /// shown makes the exact layer always kick in, and keeps previews cheap.
  /// The steps are coarse so previews are only redone on a big zoom change.
  double _pageRenderingScale(
    BuildContext context,
    PdfPage page,
    PdfViewerController controller,
    double estimatedScale,
  ) {
    const step = 1.5;
    const floor = 0.5;
    final shown =
        controller.currentZoom * MediaQuery.devicePixelRatioOf(context);
    var scale = floor;
    while (scale * step < shown && scale * step <= estimatedScale) {
      scale *= step;
    }
    return scale;
  }

  Widget _scrollThumb(
    BuildContext context,
    Size thumbSize,
    int? pageNumber,
    PdfViewerController controller,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x99808080),
      borderRadius: BorderRadius.circular(5),
    ),
  );

  /// Asks for a page number and goes there. Persian and Arabic digits are
  /// accepted as typed.
  Future<void> _askPage() async {
    final l = AppLocalizations.of(context);
    final field = TextEditingController();
    int? parse(String text) {
      final western = text.trim().replaceAllMapped(
        RegExp('[\u06F0-\u06F9\u0660-\u0669]'),
        (m) => '${m[0]!.codeUnitAt(0) & 0xF}',
      );
      final page = int.tryParse(western);
      return page == null || page < 1 || page > _pageCount ? null : page;
    }

    final page = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.goToPage),
        content: SizedBox(
          width: 220,
          child: TextField(
            controller: field,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: l.pageNumberHint(localNumber(context, _pageCount)),
            ),
            onSubmitted: (v) => Navigator.pop(context, parse(v)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, parse(field.text)),
            child: Text(l.go),
          ),
        ],
      ),
    );
    if (page != null) _controller.goToPage(pageNumber: page);
  }

  void _setTint(PageTint tint) {
    setState(() => _state = _state.copyWith(tint: tint));
    _scheduleSave();
  }

  /// Turns the page dark, or back to the paper it had before.
  void _togglePageDark() {
    final tint = _state.tint;
    if (tint.isDark) {
      _setTint(tint.copyWith(paper: _paperBeforeDark ?? PagePaper.original));
    } else {
      _paperBeforeDark = tint.paper;
      _setTint(tint.copyWith(paper: PagePaper.dark));
    }
  }

  // Links

  void _onLinkTap(PdfLink link) {
    if (link.dest != null) {
      _controller.goToDest(link.dest);
    } else if (link.url != null) {
      _openLink(link.url.toString());
    } else if (_lastDown != null) {
      _openFileLinkAt(_controller.localToDocument(_lastDown!));
    }
  }

  /// Opens a video, a file or a web page that a link points at, outside
  /// the app.
  Future<void> _openLink(String target) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).linkFailed(target);
    if (!await openBookLink(_library, widget.book, target)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  /// Opens the file a link at [documentPosition] points at, if there is
  /// one; the viewer doesn't report links of that kind itself.
  Future<void> _openFileLinkAt(Offset documentPosition) async {
    if (!_controller.isReady) return;
    final hit = _controller.getPdfPageHitTestResult(
      documentPosition,
      useDocumentLayoutCoordinates: true,
    );
    if (hit == null) return;
    String? target;
    try {
      target = await fileLinkAt(
        _controller.document,
        hit.page.pageNumber,
        hit.offset.x,
        hit.offset.y,
      );
    } catch (_) {
      return;
    }
    if (target != null && mounted) await _openLink(target);
  }

  // Highlights

  void _loadAnnotations() {
    _annotations = _library.annotations(widget.book.id);
    _byPage = {};
    for (final annotation in _annotations) {
      (_byPage[annotation.page] ??= []).add(annotation);
    }
  }

  void _reloadAnnotations() {
    setState(_loadAnnotations);
    if (_controller.isReady) _controller.invalidate();
  }

  void _onSelectionChanged(PdfTextSelection selection) {
    _selection = selection;
    final has = selection.hasSelectedText;
    if (has == _hasSelection || !mounted) return;
    // Selection callbacks can arrive mid-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasSelection = has);
    });
  }

  Future<void> _highlightSelection() async {
    final selection = _selection;
    if (selection == null || !selection.hasSelectedText) return;
    final ranges = await selection.getSelectedTextRanges();
    for (final range in ranges) {
      final rects = <double>[
        for (final fragment in range.enumerateFragmentBoundingRects()) ...[
          fragment.bounds.left,
          fragment.bounds.top,
          fragment.bounds.right,
          fragment.bounds.bottom,
        ],
      ];
      final text = range.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (rects.isEmpty || text.isEmpty) continue;
      _library.addHighlight(
        bookId: widget.book.id,
        page: range.pageNumber,
        color: _color,
        rects: rects,
        text: text,
      );
    }
    if (_controller.isReady) {
      await _controller.textSelectionDelegate.clearTextSelection();
    }
    if (mounted) _reloadAnnotations();
  }

  Future<void> _translateSelection() async {
    final selection = _selection;
    if (selection == null || !selection.hasSelectedText) return;
    final selected = await selection.getSelectedText();
    final text = selected.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty && mounted) await showTranslation(context, text);
  }

  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final unit = pageRect.width / page.width;
    Offset at(double x, double y) => PdfRect(
      x,
      y,
      x,
      y,
    ).toRectInDocument(page: page, pageRect: pageRect).topLeft;

    for (final annotation in _byPage[page.pageNumber] ?? const <Annotation>[]) {
      final r = _placeOf(annotation);
      switch (annotation.kind) {
        case AnnotationKind.ink:
          paintMark(canvas, annotation.mark!, at, unit);
        case AnnotationKind.sticky:
          if (r.length >= 2) {
            paintSticky(
              canvas,
              annotation,
              at(r[0], r[1]),
              unit,
              height: _stickyHeight(annotation),
            );
          }
        case AnnotationKind.page:
          if (r.length >= 2) {
            _paintPageIcon(canvas, at(r[0], r[1]), unit);
          }
        case AnnotationKind.highlight:
          final paint = highlighterPaint(annotation.color.marker);
          for (var i = 0; i + 3 < r.length; i += 4) {
            canvas.drawRect(
              PdfRect(
                r[i],
                r[i + 1],
                r[i + 2],
                r[i + 3],
              ).toRectInDocument(page: page, pageRect: pageRect),
              paint,
            );
          }
      }
    }
    if (_live != null && _livePage == page.pageNumber) {
      paintMark(canvas, _live!, at, unit);
    }
  }

  /// Height of a sticky note in PDF points, kept until its text changes
  /// since this is asked on every repaint.
  double _stickyHeight(Annotation sticky) {
    final cached = _stickyHeights[sticky.id];
    if (cached != null && cached.$1 == sticky.note) return cached.$2;
    final height = stickyHeight(sticky);
    _stickyHeights[sticky.id] = (sticky.note, height);
    return height;
  }

  void _paintPageIcon(Canvas canvas, Offset corner, double unit) {
    final rect = corner & (_pageIcon * unit);
    final sheet = RRect.fromRectAndRadius(rect, Radius.circular(2 * unit));
    canvas.drawRRect(
      sheet.shift(Offset(0, 1.5 * unit)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * unit),
    );
    canvas.drawRRect(sheet, Paint()..color = const Color(0xFFFFFEFA));
    canvas.drawRRect(
      sheet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit
        ..color = const Color(0xFF1F6FEB),
    );
    final line = Paint()
      ..color = const Color(0xFF1F6FEB)
      ..strokeWidth = 1.2 * unit;
    for (var i = 0; i < 3; i++) {
      final y = rect.top + (8 + i * 5) * unit;
      canvas.drawLine(
        Offset(rect.left + 4 * unit, y),
        Offset(rect.right - 4 * unit, y),
        line,
      );
    }
  }

  // Moving sticky notes and attached pages

  /// Where a placed annotation sits: its saved spot, or the spot under the
  /// pointer while it is being dragged.
  List<double> _placeOf(Annotation annotation) =>
      annotation.id == _moveId && _movePlace != null
      ? _movePlace!
      : annotation.rects;

  /// Size of a sticky note or attached-page icon in PDF points; null for
  /// annotations that aren't placed objects.
  Size? _boxOf(Annotation annotation) => switch (annotation.kind) {
    AnnotationKind.sticky => Size(stickyWidth, _stickyHeight(annotation)),
    AnnotationKind.page => _pageIcon,
    _ => null,
  };

  /// The sticky note or attached page under a point of a page, if any.
  Annotation? _movableAt(({int page, double x, double y}) point) {
    final onPage = _byPage[point.page] ?? const <Annotation>[];
    for (final annotation in onPage.reversed) {
      final box = _boxOf(annotation);
      final r = annotation.rects;
      // PDF space has its origin at the bottom left, so a box that hangs
      // down from its corner spans y - height .. y.
      if (box != null &&
          r.length >= 2 &&
          point.x >= r[0] &&
          point.x <= r[0] + box.width &&
          point.y <= r[1] &&
          point.y >= r[1] - box.height) {
        return annotation;
      }
    }
    return null;
  }

  /// Picks up [annotation] at viewer position [local].
  void _beginMove(Annotation annotation, Offset local) {
    final point = _pagePoint(local);
    final r = annotation.rects;
    if (point == null || r.length < 2) return;
    _moveId = annotation.id;
    _movePage = annotation.page;
    _moveGrip = Offset(r[0] - point.x, r[1] - point.y);
    _movePlace = null;
  }

  void _moveTo(Offset local) {
    final point = _pagePoint(local);
    // It stays on its own page.
    if (_moveId == null || point == null || point.page != _movePage) return;
    setState(
      () => _movePlace = [point.x + _moveGrip.dx, point.y + _moveGrip.dy],
    );
    _controller.invalidate();
  }

  /// Drops what was being moved. Returns the annotation if it was only
  /// pressed and never dragged, so the caller can treat that as a tap.
  Annotation? _endMove() {
    final id = _moveId;
    final place = _movePlace;
    _moveId = null;
    _movePlace = null;
    if (id == null) return null;
    if (place == null) return _library.annotation(id);
    _library.moveAnnotation(id, place[0], place[1]);
    _reloadAnnotations();
    return null;
  }

  void _openOrEdit(Annotation annotation) {
    if (annotation.kind == AnnotationKind.page) {
      _openAttachedPage(annotation);
    } else {
      _editAnnotation(annotation);
    }
  }

  /// Invisible handles over the sticky notes and attached pages of a page,
  /// so they can be dragged and pressed while the page itself still pans.
  List<Widget> _placedHandles(
    BuildContext context,
    Rect pageRect,
    PdfPage page,
  ) {
    final unit = pageRect.width / page.width;
    return [
      for (final annotation in _byPage[page.pageNumber] ?? const <Annotation>[])
        if (_boxOf(annotation) case final box?)
          if (_placeOf(annotation) case [final x, final y, ...])
            Positioned.fromRect(
              key: ValueKey(annotation.id),
              rect:
                  PdfRect(
                    x,
                    y,
                    x,
                    y,
                  ).toRect(page: page, scaledPageSize: pageRect.size).topLeft &
                  box * unit,
              child: MouseRegion(
                cursor: _moveId == annotation.id
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openOrEdit(annotation),
                  onPanStart: (details) {
                    final local = _controller.globalToLocal(
                      details.globalPosition,
                    );
                    if (local != null) _beginMove(annotation, local);
                  },
                  onPanUpdate: (details) {
                    final local = _controller.globalToLocal(
                      details.globalPosition,
                    );
                    if (local != null) _moveTo(local);
                  },
                  onPanEnd: (_) => _endMove(),
                  onPanCancel: _endMove,
                ),
              ),
            ),
    ];
  }

  // Drawing

  ({int page, double x, double y})? _pagePoint(Offset local) {
    final hit = _controller.getPdfPageHitTestResult(
      _controller.localToDocument(local),
      useDocumentLayoutCoordinates: true,
    );
    if (hit == null) return null;
    return (page: hit.page.pageNumber, x: hit.offset.x, y: hit.offset.y);
  }

  void _drawDown(PointerDownEvent event) {
    final point = _pagePoint(event.localPosition);
    // The overlay takes the press from the viewer, so it takes the
    // keyboard for it too.
    _controller.requestFocus();
    if (point == null) return;
    _downAt = event.localPosition;
    _dragged = false;
    _livePage = point.page;
    // A press on a sticky note or attached page picks it up, whatever tool
    // is in hand.
    final movable = _movableAt(point);
    if (movable != null) {
      _beginMove(movable, event.localPosition);
      return;
    }
    if (_tools.tool == DrawTool.eraser) {
      _eraseAt(point);
    } else if (_tools.markTool != null && _tools.tool != DrawTool.text) {
      // Pages are laid out one PDF point to a pixel at zoom 1.
      _sampler = StrokeSampler(
        pixel: 1 / _controller.currentZoom,
        precise: isPrecise(event),
      )..add(point.x, point.y, pressure: stylusPressure(event));
      _live = _tools.mark([point.x, point.y]);
      _controller.invalidate();
    }
  }

  void _drawMove(PointerMoveEvent event) {
    if (_downAt != null && (event.localPosition - _downAt!).distance > 3) {
      _dragged = true;
    }
    if (_moveId != null) {
      if (_dragged) _moveTo(event.localPosition);
      return;
    }
    final point = _pagePoint(event.localPosition);
    // A drawing belongs to the page it started on.
    if (point == null || point.page != _livePage) return;
    if (_tools.tool == DrawTool.eraser) {
      _eraseAt(point);
      return;
    }
    final live = _live;
    if (live == null) return;
    if (live.isFreehand) {
      final sampler = _sampler!;
      if (!sampler.add(point.x, point.y, pressure: stylusPressure(event))) {
        return;
      }
      _live = _strokeOf(live, sampler);
    } else {
      final p = live.points;
      _live = live.copyWith(points: [p[0], p[1], point.x, point.y]);
    }
    _controller.invalidate();
  }

  /// The mark with the sampler's points so far, weighted along its length
  /// when the tool or a stylus calls for it.
  Mark _strokeOf(Mark mark, StrokeSampler sampler) => mark.copyWith(
    points: List.of(sampler.points),
    widths: _tools.isExpressive || sampler.hasPressure
        ? List.of(sampler.widths)
        : null,
  );

  Future<void> _drawUp(PointerEvent event) async {
    if (_moveId != null) {
      _downAt = null;
      _livePage = null;
      final pressed = _endMove();
      if (pressed != null) _openOrEdit(pressed);
      return;
    }
    final point = _pagePoint(event.localPosition);
    final page = _livePage;
    var live = _live;
    if (live != null && live.isFreehand && _sampler != null) {
      if (point != null && point.page == page) {
        _sampler!.finish(point.x, point.y);
      }
      live = _strokeOf(live, _sampler!);
    }
    _sampler = null;
    final tapped = !_dragged && point != null && point.page == page;
    _live = null;
    _livePage = null;
    _downAt = null;

    switch (_tools.tool) {
      case DrawTool.eraser:
        return;
      case DrawTool.sticky:
        if (!tapped) return;
        final sticky = _library.addSticky(
          bookId: widget.book.id,
          page: point.page,
          x: point.x,
          y: point.y,
          color: _color,
        );
        _undo.add((id: sticky.id, added: true));
        _reloadAnnotations();
        await _editAnnotation(sticky);
      case DrawTool.page:
        if (!tapped) return;
        final sheet = _library.addPage(_library.notebookFor(widget.book).id);
        final link = _library.addPageLink(
          bookId: widget.book.id,
          page: point.page,
          x: point.x,
          y: point.y,
          pageId: sheet.id,
        );
        _undo.add((id: link.id, added: true));
        _reloadAnnotations();
        if (mounted) await openNotebookPage(context, sheet.id);
      case DrawTool.text:
        if (!tapped) return;
        final text = await askMarkText(context);
        if (text == null || text.isEmpty || !mounted) return;
        final typed = _library.addInk(
          bookId: widget.book.id,
          page: point.page,
          mark: _tools.mark([point.x, point.y], text: text)!,
        );
        _undo.add((id: typed.id, added: true));
        _reloadAnnotations();
      default:
        // A shape needs to have been dragged out; a pen may leave a dot.
        if (live != null && page != null && (live.isFreehand || _dragged)) {
          final drawn = _library.addInk(
            bookId: widget.book.id,
            page: page,
            mark: live,
          );
          _undo.add((id: drawn.id, added: true));
        }
        _reloadAnnotations();
    }
  }

  void _eraseAt(({int page, double x, double y}) point) {
    var erased = false;
    for (final annotation in _byPage[point.page] ?? const <Annotation>[]) {
      if (annotation.isInk &&
          annotation.mark!.hit(point.x, point.y, _pickReach)) {
        _library.removeAnnotation(annotation.id);
        _undo.add((id: annotation.id, added: false));
        erased = true;
      }
    }
    if (erased) _reloadAnnotations();
  }

  void _setDraw(bool draw) {
    setState(() => _draw = draw);
    _library.setSetting('reader.draw', draw ? '1' : '0');
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    final step = _undo.removeLast();
    step.added
        ? _library.removeAnnotation(step.id)
        : _library.restoreAnnotation(step.id);
    _reloadAnnotations();
  }

  /// The topmost annotation under a point of the document, if any.
  Annotation? _annotationAt(Offset documentPosition) {
    final hit = _controller.getPdfPageHitTestResult(
      documentPosition,
      useDocumentLayoutCoordinates: true,
    );
    if (hit == null) return null;
    final x = hit.offset.x, y = hit.offset.y;
    final onPage = _byPage[hit.page.pageNumber] ?? const <Annotation>[];
    for (final annotation in onPage.reversed) {
      final r = annotation.rects;
      // PDF space has its origin at the bottom left, so a box that hangs
      // down from its corner spans y - height .. y.
      bool inBox(double width, double height) =>
          r.length >= 2 &&
          x >= r[0] &&
          x <= r[0] + width &&
          y <= r[1] &&
          y >= r[1] - height;
      final found = switch (annotation.kind) {
        AnnotationKind.ink => annotation.mark!.hit(x, y, _pickReach),
        AnnotationKind.sticky => inBox(stickyWidth, _stickyHeight(annotation)),
        AnnotationKind.page => inBox(_pageIcon.width, _pageIcon.height),
        AnnotationKind.highlight => () {
          for (var i = 0; i + 3 < r.length; i += 4) {
            if (x >= r[i] && x <= r[i + 2] && y <= r[i + 1] && y >= r[i + 3]) {
              return true;
            }
          }
          return false;
        }(),
      };
      if (found) return annotation;
    }
    return null;
  }

  bool _onTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type != PdfViewerGeneralTapType.tap || _hasSelection) {
      return false;
    }
    final annotation = _annotationAt(details.documentPosition);
    if (annotation == null) {
      _openFileLinkAt(details.documentPosition);
      return false;
    }
    if (annotation.kind == AnnotationKind.page) {
      _openAttachedPage(annotation);
    } else {
      _editAnnotation(annotation);
    }
    return true;
  }

  void _openAttachedPage(Annotation link) {
    if (_library.page(link.text) != null) {
      openNotebookPage(context, link.text);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).pageGone)),
    );
  }

  Future<void> _editAnnotation(Annotation annotation) async {
    final color = await showAnnotationDialog(
      context,
      library: _library,
      annotation: annotation,
      onChanged: _reloadAnnotations,
    );
    if (color != null) _setColor(color);
  }

  /// Picks the color new highlights and sticky notes get.
  void _setColor(HighlightColor color) {
    if (color == _color) return;
    setState(() => _color = color);
    _library.setSetting('reader.highlightColor', color.name);
  }

  /// Brings [annotation] to the middle of the view, at the zoom the reader
  /// is already at.
  void _goToAnnotation(Annotation annotation, {bool animate = true}) {
    final r = annotation.rects;
    if (r.length < 4) {
      _controller.goToPage(pageNumber: annotation.page);
      return;
    }
    final spot = _controller.calcRectForRectInsidePage(
      pageNumber: annotation.page,
      rect: PdfRect(r[0], r[1], r[2], r[3]),
    );
    _controller.goTo(
      _controller.calcMatrixFor(spot.center),
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
    );
  }

  void _togglePanel({required bool wide}) {
    if (wide) {
      setState(() => _showPanel = !_showPanel);
      _library.setSetting('reader.panel', _showPanel ? '1' : '0');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: HighlightsPanel(
          annotations: _annotations,
          onOpen: (a) {
            Navigator.pop(sheetContext);
            _goToAnnotation(a);
          },
          onEdit: (a) {
            Navigator.pop(sheetContext);
            _editAnnotation(a);
          },
        ),
      ),
    );
  }

  // Find in book

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _toggleFind() {
    setState(() => _finding = !_finding);
    if (_finding) {
      _findFocus.requestFocus();
    } else {
      _findText.clear();
      _searcher?.resetTextSearch();
    }
  }

  void _find(String text) {
    if (text.trim().isEmpty) {
      _searcher?.resetTextSearch();
    } else {
      _searcher?.startTextSearch(text.trim());
    }
  }

  Widget _findBar(AppLocalizations l, ThemeData theme) {
    final searcher = _searcher;
    final count = searcher?.matches.length ?? 0;
    final index = searcher?.currentIndex;
    final String status;
    if (_findText.text.trim().isEmpty) {
      status = '';
    } else if (count == 0) {
      status = searcher?.isSearching ?? false ? '…' : l.noMatches;
    } else {
      status = l.matchOf(
        localNumber(context, (index ?? 0) + 1),
        localNumber(context, count),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: MacColors.of(context).toolbar,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        spacing: 6,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: MacSearchField(
                controller: _findText,
                focusNode: _findFocus,
                hint: l.findHint,
                onChanged: _find,
                onSubmitted: (_) {
                  searcher?.goToNextMatch();
                  _findFocus.requestFocus();
                },
              ),
            ),
          ),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          MacIconButton(
            icon: CupertinoIcons.chevron_up,
            tooltip: l.previous,
            onPressed: count > 0 ? () => searcher?.goToPrevMatch() : null,
          ),
          MacIconButton(
            icon: CupertinoIcons.chevron_down,
            tooltip: l.next,
            onPressed: count > 0 ? () => searcher?.goToNextMatch() : null,
          ),
          TextButton(onPressed: _toggleFind, child: Text(l.done)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tint = _state.tint;
    final wide = MediaQuery.sizeOf(context).width >= _panelLayout;

    final backdrop = tint.recolors
        ? _tintedBackdrop
        : theme.colorScheme.surfaceContainerLowest;

    Widget viewer;
    if (!_fileExists) {
      viewer = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.bookFileMissing, textAlign: TextAlign.center),
        ),
      );
    } else {
      viewer = PdfViewer.file(
        _path,
        controller: _controller,
        initialPageNumber: _state.page,
        params: PdfViewerParams(
          // The tint filter covers the whole viewer, so under a paper preset
          // the backdrop is a neutral gray that lands just off the paper.
          backgroundColor: backdrop,
          // Inverted, the default shadow would turn into a pale glow.
          pageDropShadow: tint.isDark
              ? null
              : const PdfViewerParams().pageDropShadow,
          textSelectionParams: _selectionParams,
          // 0.2 of the view per wheel notch is the viewer's own default.
          scrollByMouseWheel: 0.2 * _appState.scrollSpeed,
          interactionDelegateProvider: _appState.smoothScroll
              ? const PdfViewerScrollInteractionDelegateProviderPhysics()
              : const PdfViewerScrollInteractionDelegateProviderInstant(),
          getPageRenderingScale: _pageRenderingScale,
          onViewerReady: _onViewerReady,
          onGeneralTap: _onTap,
          // Shortcuts work as soon as the book is open.
          keyHandlerParams: const PdfViewerKeyHandlerParams(autofocus: true),
          // The pointer turns into a hand over a link, which is enough of
          // a sign; tinting every link would color tables of contents.
          linkHandlerParams: PdfLinkHandlerParams(
            onLinkTap: _onLinkTap,
            linkColor: Colors.transparent,
          ),
          pageOverlaysBuilder: _placedHandles,
          // Draggable thumbs: down the side for pages, along the bottom for
          // moving sideways when zoomed in.
          viewerOverlayBuilder: (context, size, handleLinkTap) => [
            PdfViewerScrollThumb(
              controller: _controller,
              orientation: ScrollbarOrientation.right,
              thumbSize: const Size(10, 56),
              thumbBuilder: _scrollThumb,
            ),
            PdfViewerScrollThumb(
              controller: _controller,
              orientation: ScrollbarOrientation.bottom,
              thumbSize: const Size(56, 10),
              thumbBuilder: _scrollThumb,
            ),
          ],
          pagePaintCallbacks: [
            _paintHighlights,
            if (_searcher != null) _searcher!.pageTextMatchPaintCallback,
          ],
          customizeContextMenuItems: (params, items) {
            if (!params.textSelectionDelegate.hasSelectedText) return;
            items.add(
              ContextMenuButtonItem(
                label: l.highlight,
                onPressed: () {
                  params.dismissContextMenu();
                  _highlightSelection();
                },
              ),
            );
            items.add(
              ContextMenuButtonItem(
                label: l.translate,
                onPressed: () {
                  params.dismissContextMenu();
                  _translateSelection();
                },
              ),
            );
          },
        ),
      );
      // The overlay takes drags for drawing; the mouse wheel still
      // scrolls and zooms the page underneath. The stack stays when the pen
      // is off, so the viewer isn't rebuilt each time it's toggled.
      viewer = Stack(
        children: [
          Listener(
            onPointerDown: (event) => _lastDown = event.localPosition,
            child: viewer,
          ),
          if (_draw)
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _drawDown,
                onPointerMove: _drawMove,
                onPointerUp: _drawUp,
                onPointerCancel: _drawUp,
                onPointerSignal: _controller.handlePointerSignalEvent,
              ),
            ),
        ],
      );
      final filter = tint.filter;
      final filtered = filter == null
          ? viewer
          : ColorFiltered(colorFilter: filter, child: viewer);
      // Pages are centered in the viewer, so an odd pixel width puts every
      // page half a pixel off the grid and softens its text. Trimming the
      // viewer to even pixels keeps pages on whole pixels.
      viewer = LayoutBuilder(
        builder: (context, constraints) {
          final ratio = MediaQuery.devicePixelRatioOf(context);
          double even(double logical) {
            final pixels = (logical * ratio).floor();
            return (pixels - pixels % 2) / ratio;
          }

          return ColoredBox(
            color: tint.apply(backdrop),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: even(constraints.maxWidth),
                height: even(constraints.maxHeight),
                child: filtered,
              ),
            ),
          );
        },
      );
    }

    // The tool picker floats over the page, outside the page tint. Under
    // bars that float, the page runs to the screen's bottom edge, so the
    // picker stands clear of the page bar and the system's navigation.
    final floatingBars = _autoHide && !_focus;
    final toolsBottom =
        14.0 +
        (floatingBars
            ? MediaQuery.paddingOf(context).bottom +
                  (_ready && _pageCount > 1 ? _pageBarHeight + 1 : 0)
            : 0);
    viewer = Stack(
      children: [
        Positioned.fill(child: viewer),
        if (_draw && _fileExists)
          Positioned(
            left: 12,
            right: 12,
            bottom: toolsBottom,
            child: Center(
              child: DrawToolbar(
                settings: _tools,
                bookTools: true,
                onUndo: _undo.isEmpty ? null : _undoLast,
                onClose: () => _setDraw(false),
              ),
            ),
          ),
      ],
    );

    viewer = KeyedSubtree(key: _viewerKey, child: viewer);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_focus) {
            setState(() => _focus = false);
          } else if (_finding) {
            _toggleFind();
          }
        },
        AppKeys.focusMode: _toggleFocus,
        AppKeys.pageDark: _togglePageDark,
        AppKeys.autoHide: _toggleAutoHide,
        AppKeys.closeBook: _close,
        AppKeys.find: () {
          if (_ready) _finding ? _findFocus.requestFocus() : _toggleFind();
        },
        AppKeys.goToPage: () {
          if (_ready && _pageCount > 1) _askPage();
        },
        AppKeys.highlight: _highlightSelection,
        AppKeys.draw: () {
          if (_ready) _setDraw(!_draw);
        },
        AppKeys.undo: _undoLast,
      },
      child: _scaffold(l, theme, tint, wide, viewer),
    );
  }

  void _toggleFocus() => setState(() {
    _focus = !_focus;
    if (_focus) _draw = false;
  });

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _scaffold(
    AppLocalizations l,
    ThemeData theme,
    PageTint tint,
    bool wide,
    Widget viewer,
  ) {
    if (_focus) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: SafeArea(child: viewer)),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: SafeArea(
                child: Opacity(
                  opacity: 0.55,
                  child: MacIconButton(
                    icon: CupertinoIcons.fullscreen_exit,
                    tooltip: l.exitFocus,
                    onPressed: () => setState(() => _focus = false),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Shown as buttons where there is room for them, otherwise in a menu.
    final more = [
      if (widget.onOpenBeside != null)
        _ToolbarAction(
          icon: CupertinoIcons.square_split_2x1,
          label: l.openBeside,
          onPressed: widget.onOpenBeside,
        ),
      if (widget.onNewWindow != null)
        _ToolbarAction(
          icon: CupertinoIcons.macwindow,
          label: l.moveToNewWindow,
          onPressed: widget.onNewWindow,
        ),
      if (widget.link case final link?)
        _ToolbarAction(
          icon: CupertinoIcons.link,
          label: l.scrollTogether,
          active: link.isOn,
          onPressed: link.toggle,
        ),
      _ToolbarAction(
        icon: CupertinoIcons.globe,
        label: l.translate,
        hint: l.translateHint,
        onPressed: _hasSelection ? _translateSelection : null,
      ),
      _ToolbarAction(
        icon: CupertinoIcons.square_arrow_up,
        label: l.exportPdf,
        onPressed: _fileExists
            ? () => showPdfExportDialog(context, widget.book)
            : null,
      ),
      _ToolbarAction(
        icon: CupertinoIcons.sidebar_right,
        label: l.highlights,
        active: wide && _showPanel,
        onPressed: () => _togglePanel(wide: wide),
      ),
      _ToolbarAction(
        icon: CupertinoIcons.minus,
        label: l.zoomOut,
        onPressed: _ready ? () => _controller.zoomDown() : null,
      ),
      _ToolbarAction(
        icon: CupertinoIcons.plus,
        label: l.zoomIn,
        onPressed: _ready ? () => _controller.zoomUp() : null,
      ),
      _ToolbarAction(
        icon: CupertinoIcons.fullscreen,
        label: withShortcut(l.focusMode, AppKeys.focusMode),
        onPressed: _toggleFocus,
      ),
      _ToolbarAction(
        icon: CupertinoIcons.circle_lefthalf_fill,
        label: l.pageColor,
        active: !tint.isIdentity,
        onPressed: () =>
            showTintSheet(context, initial: _state.tint, onChanged: _setTint),
      ),
    ];
    // Search, highlight, its color and drawing always show.
    final compact =
        MediaQuery.sizeOf(context).width <
        _toolbarTitle + _toolbarButton * (4 + more.length);
    final toolbar = MacToolbar(
      leading: widget.onClose == null
          ? MacIconButton(
              icon: CupertinoIcons.chevron_back,
              tooltip: l.back,
              onPressed: () => Navigator.of(context).pop(),
            )
          : MacIconButton(
              icon: CupertinoIcons.xmark,
              tooltip: l.close,
              onPressed: widget.onClose,
            ),
      title: widget.book.title,
      actions: [
        MacIconButton(
          icon: CupertinoIcons.search,
          tooltip: withShortcut(l.findInBook, AppKeys.find),
          active: _finding,
          onPressed: _ready ? _toggleFind : null,
        ),
        Tooltip(
          message: _hasSelection
              ? withShortcut(l.highlight, AppKeys.highlight)
              : l.highlightHint,
          child: IconButton(
            onPressed: _hasSelection ? _highlightSelection : null,
            icon: Icon(
              Icons.border_color_outlined,
              color: _hasSelection ? null : theme.disabledColor,
            ),
            style: _hasSelection
                ? IconButton.styleFrom(backgroundColor: _color.marker)
                : null,
          ),
        ),
        PopupMenuButton<HighlightColor>(
          tooltip: l.highlightColor,
          position: PopupMenuPosition.under,
          onSelected: _setColor,
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: HighlightColorPicker(
                value: _color,
                onChanged: (color) => Navigator.of(context).pop(color),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _color.swatch,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ),
        ),
        MacIconButton(
          icon: CupertinoIcons.pencil,
          tooltip: withShortcut(l.drawTools, AppKeys.draw),
          active: _draw,
          onPressed: _ready ? () => _setDraw(!_draw) : null,
        ),
        if (compact)
          PopupMenuButton<VoidCallback>(
            tooltip: l.moreActions,
            position: PopupMenuPosition.under,
            icon: const Icon(CupertinoIcons.ellipsis),
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              for (final item in more)
                PopupMenuItem(
                  value: item.onPressed,
                  enabled: item.onPressed != null,
                  height: 38,
                  child: Row(
                    spacing: 10,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: item.onPressed == null
                            ? theme.disabledColor
                            : item.active
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      Flexible(child: Text(item.label)),
                    ],
                  ),
                ),
            ],
          )
        else
          for (final item in more)
            MacIconButton(
              icon: item.icon,
              tooltip: item.onPressed == null
                  ? item.hint ?? item.label
                  : item.label,
              active: item.active,
              onPressed: item.onPressed,
            ),
      ],
    );
    final extras = [
      if (_ready && _elsewhere != null) _continueBar(l, theme),
      if (_finding) _findBar(l, theme),
    ];
    final content = Row(
      children: [
        Expanded(child: viewer),
        if (wide && _showPanel) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 290,
            child: Padding(
              // Under bars that float, the list starts below the toolbar.
              padding: EdgeInsets.only(
                top: _autoHide
                    ? MacToolbar.height + MediaQuery.paddingOf(context).top
                    : 0,
              ),
              child: HighlightsPanel(
                annotations: _annotations,
                onOpen: _goToAnnotation,
                onEdit: _editAnnotation,
              ),
            ),
          ),
        ],
      ],
    );
    final pageBar = _ready && _pageCount > 1
        ? Container(
            decoration: BoxDecoration(
              color: MacColors.of(context).toolbar,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              // A slider fills whatever height it is offered, so pin it.
              child: Container(
                height: _pageBarHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: CupertinoSlider(
                        min: 1,
                        max: _pageCount.toDouble(),
                        value: (_dragPage ?? _state.page.toDouble()).clamp(
                          1,
                          _pageCount.toDouble(),
                        ),
                        onChanged: (v) => setState(() => _dragPage = v),
                        onChangeEnd: (v) {
                          setState(() => _dragPage = null);
                          _controller.goToPage(pageNumber: v.round());
                        },
                      ),
                    ),
                    Tooltip(
                      message: l.goToPage,
                      child: InkWell(
                        onTap: _askPage,
                        borderRadius: BorderRadius.circular(5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            l.pageOf(
                              localNumber(
                                context,
                                (_dragPage ?? _state.page).round(),
                              ),
                              localNumber(context, _pageCount),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
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
          )
        : null;

    if (_autoHide) {
      return Scaffold(
        body: AutoHideBars(
          top: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [toolbar, ...extras],
          ),
          body: content,
          bottom: pageBar,
          // Kept while finding, so the search field doesn't slip away.
          hold: _finding,
        ),
      );
    }
    return Scaffold(
      appBar: toolbar,
      body: Column(
        children: [
          ...extras,
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: pageBar,
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../draw/draw_tools.dart';
import '../draw/mark.dart';
import '../l10n/app_localizations.dart';
import 'page_surface.dart';

/// Opens a notebook page for writing and drawing.
Future<void> openNotebookPage(BuildContext context, String pageId) async {
  final state = AppScope.read(context);
  // Remembered so the app can reopen the page it was closed on.
  state.library.setSetting('session.page', pageId);
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => PageEditor(pageId: pageId)));
  state.library.setSetting('session.page', null);
  state.refresh();
}

/// Asks for the text of a text mark. Returns null if cancelled.
Future<String?> askMarkText(BuildContext context, {String initial = ''}) {
  final l = AppLocalizations.of(context);
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.toolText),
      content: SizedBox(
        width: 340,
        child: TextField(
          controller: field,
          autofocus: true,
          minLines: 2,
          maxLines: 8,
          decoration: InputDecoration(hintText: l.textHint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, field.text.trim()),
          child: Text(initial.isEmpty ? l.add : l.save),
        ),
      ],
    ),
  );
}

/// How near, in page points, the eraser must pass to take a mark.
const _eraserReach = 6.0;

/// Pressure of a pointer as 0..1 when it comes from a stylus that reports
/// it, otherwise null.
double? stylusPressure(PointerEvent event) {
  final stylus =
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus;
  final range = event.pressureMax - event.pressureMin;
  if (!stylus || range <= 0) return null;
  return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
}

/// Whether a pointer reports positions finer than a pixel. A mouse moves in
/// whole pixels; a finger or stylus does not.
bool isPrecise(PointerEvent event) => event.kind != PointerDeviceKind.mouse;

const _undoDepth = 80;

/// One notebook page with the tool picker: write with pens, mark with the
/// highlighter, draw shapes, type text, erase, undo and redo.
class PageEditor extends StatefulWidget {
  const PageEditor({super.key, required this.pageId});

  final String pageId;

  @override
  State<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<PageEditor> {
  late final AppState _state = AppScope.read(context);
  late final Library _library = _state.library;
  late final DrawSettings _tools = DrawSettings(_library);
  final _scroll = ScrollController();

  late String _pageId = widget.pageId;
  late String _notebookId;
  var _paper = PaperStyle.blank;
  var _marks = <Mark>[];
  final _undo = <List<Mark>>[];
  final _redo = <List<Mark>>[];
  Mark? _live;
  StrokeSampler? _sampler;
  Offset? _downAt;
  var _dragged = false;
  Timer? _saveTimer;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    _load(widget.pageId);
  }

  void _load(String id) {
    final page = _library.page(id);
    _pageId = id;
    _notebookId = page?.notebookId ?? '';
    _paper = page?.paper ?? PaperStyle.blank;
    _marks = page?.marks ?? [];
    _undo.clear();
    _redo.clear();
    _live = null;
  }

  @override
  void dispose() {
    _flush();
    _tools.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    _library.savePage(_pageId, marks: _marks);
  }

  /// Replaces the page's marks, remembering the old ones for undo.
  void _commit(List<Mark> marks) {
    _undo.add(_marks);
    if (_undo.length > _undoDepth) _undo.removeAt(0);
    _redo.clear();
    setState(() => _marks = marks);
    _touch();
  }

  void _touch() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flush);
  }

  void _stepHistory(List<List<Mark>> from, List<List<Mark>> to) {
    if (from.isEmpty) return;
    to.add(_marks);
    setState(() => _marks = from.removeLast());
    _touch();
  }

  void _goTo(String pageId) {
    _flush();
    setState(() => _load(pageId));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // Pointer handling. [unit] is screen pixels per page point.

  void _down(PointerDownEvent event, double unit) {
    final x = event.localPosition.dx / unit, y = event.localPosition.dy / unit;
    _downAt = event.localPosition;
    _dragged = false;
    if (_tools.tool == DrawTool.eraser) {
      _undo.add(_marks);
      _redo.clear();
      _erase(x, y);
    } else if (_tools.tool != DrawTool.text) {
      _sampler = StrokeSampler(pixel: 1 / unit, precise: isPrecise(event))
        ..add(x, y, pressure: stylusPressure(event));
      setState(() => _live = _tools.mark([x, y]));
    }
  }

  void _move(PointerMoveEvent event, double unit) {
    final x = event.localPosition.dx / unit, y = event.localPosition.dy / unit;
    if (_downAt != null && (event.localPosition - _downAt!).distance > 3) {
      _dragged = true;
    }
    if (_tools.tool == DrawTool.eraser) {
      _erase(x, y);
      return;
    }
    final live = _live;
    if (live == null) return;
    if (live.isFreehand) {
      final sampler = _sampler!;
      if (!sampler.add(x, y, pressure: stylusPressure(event))) return;
      setState(() => _live = _strokeOf(live, sampler));
    } else {
      final p = live.points;
      setState(() => _live = live.copyWith(points: [p[0], p[1], x, y]));
    }
  }

  /// The mark with the sampler's points so far, weighted along its length
  /// when the tool or a stylus calls for it.
  Mark _strokeOf(Mark mark, StrokeSampler sampler) => mark.copyWith(
    points: List.of(sampler.points),
    widths: _tools.isExpressive || sampler.hasPressure
        ? List.of(sampler.widths)
        : null,
  );

  Future<void> _up(PointerEvent event, double unit) async {
    final x = event.localPosition.dx / unit, y = event.localPosition.dy / unit;
    var live = _live;
    if (live != null && live.isFreehand && _sampler != null) {
      live = _strokeOf(live, _sampler!..finish(x, y));
    }
    _sampler = null;
    _downAt = null;
    if (_tools.tool == DrawTool.eraser) {
      // The snapshot taken on press is dropped if nothing was erased.
      if (_undo.isNotEmpty && identical(_undo.last, _marks)) _undo.removeLast();
      return;
    }
    if (_tools.tool == DrawTool.text) {
      if (!_dragged) await _typeAt(x, y);
      return;
    }
    if (live == null) return;
    setState(() => _live = null);
    // A shape needs to have been dragged out; a pen may leave a dot.
    if (!live.isFreehand && !_dragged) return;
    _commit([..._marks, live]);
  }

  void _erase(double x, double y) {
    final kept = [
      for (final mark in _marks)
        if (!mark.hit(x, y, _eraserReach)) mark,
    ];
    if (kept.length == _marks.length) return;
    setState(() => _marks = kept);
    _touch();
  }

  /// Adds text at the spot, or edits the text already there.
  Future<void> _typeAt(double x, double y) async {
    final existing = _marks.lastWhere(
      (m) => m.tool == MarkTool.text && m.hit(x, y, 4),
      orElse: () => const Mark(
        tool: MarkTool.text,
        color: Color(0x00000000),
        width: 0,
        points: [],
      ),
    );
    final editing = existing.points.isNotEmpty;
    final text = await askMarkText(
      context,
      initial: editing ? existing.text : '',
    );
    if (text == null || !mounted) return;
    if (editing) {
      _commit([
        for (final mark in _marks)
          if (!identical(mark, existing))
            mark
          else if (text.isNotEmpty)
            mark.copyWith(text: text),
      ]);
    } else if (text.isNotEmpty) {
      _commit([
        ..._marks,
        _tools.mark([x, y], text: text)!,
      ]);
    }
  }

  Future<void> _deletePage(List<NotebookPage> pages, int index) async {
    final navigator = Navigator.of(context);
    _saveTimer?.cancel();
    _dirty = false;
    _library.removePage(_pageId);
    if (pages.length <= 1) {
      navigator.pop();
      return;
    }
    _goTo(pages[index == 0 ? 1 : index - 1].id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pages = _library.pages(_notebookId);
    final index = pages.indexWhere((p) => p.id == _pageId);
    final notebook = _library.notebook(_notebookId);
    final paperNames = {
      PaperStyle.blank: l.paperBlank,
      PaperStyle.lined: l.paperLined,
      PaperStyle.grid: l.paperGrid,
      PaperStyle.dots: l.paperDots,
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: MacToolbar(
        leading: MacIconButton(
          icon: CupertinoIcons.chevron_back,
          tooltip: l.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: notebook?.name ?? '',
        actions: [
          MacPopupButton<PaperStyle>(
            value: _paper,
            items: paperNames,
            onChanged: (paper) {
              setState(() => _paper = paper);
              _library.savePage(_pageId, paper: paper);
            },
          ),
          const SizedBox(width: 6),
          MacIconButton(
            icon: CupertinoIcons.chevron_back,
            tooltip: l.previous,
            onPressed: index > 0 ? () => _goTo(pages[index - 1].id) : null,
          ),
          Text(
            l.pageOf(
              localNumber(context, index + 1),
              localNumber(context, pages.length),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          MacIconButton(
            icon: CupertinoIcons.chevron_forward,
            tooltip: l.next,
            onPressed: index >= 0 && index < pages.length - 1
                ? () => _goTo(pages[index + 1].id)
                : null,
          ),
          MacIconButton(
            icon: CupertinoIcons.add,
            tooltip: l.newPage,
            onPressed: () =>
                _goTo(_library.addPage(_notebookId, paper: _paper).id),
          ),
          MacIconButton(
            icon: CupertinoIcons.trash,
            tooltip: l.deletePage,
            onPressed: index < 0 ? null : () => _deletePage(pages, index),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 48).clamp(240.0, 900.0);
                final unit = width / notebookPageSize.width;
                return Listener(
                  // Dragging draws, so the page scrolls by wheel or by its
                  // scrollbar instead.
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent && _scroll.hasClients) {
                      _scroll.jumpTo(
                        (_scroll.offset +
                                signal.scrollDelta.dy * _state.scrollSpeed)
                            .clamp(0.0, _scroll.position.maxScrollExtent),
                      );
                    }
                  },
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
                      child: Center(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          // Writing is left to right or right to left by
                          // its own letters, not by the interface language.
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (e) => _down(e, unit),
                              onPointerMove: (e) => _move(e, unit),
                              onPointerUp: (e) => _up(e, unit),
                              onPointerCancel: (e) => _up(e, unit),
                              // What is already on the page sits in its own
                              // layer, so drawing a stroke repaints only
                              // that stroke, however full the page is.
                              child: ClipRect(
                                child: Stack(
                                  children: [
                                    RepaintBoundary(
                                      child: CustomPaint(
                                        size: notebookPageSize * unit,
                                        painter: PagePainter(
                                          paper: _paper,
                                          marks: _marks,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: LiveMarkPainter(_live),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              child: Center(
                child: DrawToolbar(
                  settings: _tools,
                  onUndo: _undo.isEmpty
                      ? null
                      : () => _stepHistory(_undo, _redo),
                  onRedo: _redo.isEmpty
                      ? null
                      : () => _stepHistory(_redo, _undo),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../core/app_state.dart';
import '../core/auto_hide_bars.dart';
import '../core/links.dart';
import '../core/mac_widgets.dart';
import '../core/shortcuts.dart';
import '../core/theme.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../reader/page_tint.dart';
import '../reader/scroll_link.dart';
import '../translate/translation_dialog.dart';
import 'text_book.dart';

/// Reader for reflowable books (EPUB, Markdown, HTML, plain text): one
/// section on screen at a time, set in the reader's own type size, line
/// spacing, column width and paper color.
/// Below this width the buttons for the desk go in a menu.
const _fullToolbar = 600.0;

class TextReaderScreen extends StatefulWidget {
  const TextReaderScreen({
    super.key,
    required this.book,
    this.onClose,
    this.onOpenBeside,
    this.onNewWindow,
    this.link,
  });

  final Book book;

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
  State<TextReaderScreen> createState() => _TextReaderScreenState();
}

class _TextReaderScreenState extends State<TextReaderScreen>
    with WidgetsBindingObserver
    implements LinkedReader {
  static const _saveDelay = Duration(milliseconds: 500);

  late final AppState _appState = AppScope.read(context);
  late final Library _library = _appState.library;
  final _scroll = ScrollController();
  final _keys = FocusNode();

  /// The text selected on the page; empty when none is.
  final _selected = ValueNotifier('');

  TextBook? _book;
  var _failed = false;
  var _section = 0;

  /// Scroll position to restore once the section has been laid out, 0..1.
  double? _pendingFraction;
  Timer? _saveTimer;
  var _focus = false;

  /// Set while scrolling to follow a linked book, so the move isn't
  /// passed back.
  var _following = false;

  late PagePaper _paper;

  /// The paper before the dark-page shortcut, to go back to.
  PagePaper? _paperBeforeDark;

  /// Whether the bars slide away while the mouse rests.
  late var _autoHide = _appState.autoHideBars;
  late double _size, _height, _width;

  @override
  void initState() {
    super.initState();
    final saved = _library.readingState(widget.book.id);
    _section = (saved?.page ?? 1) - 1;
    _pendingFraction = saved?.fy;
    _paper = saved?.tint.paper ?? PagePaper.original;
    _size = _setting('text.size', 17);
    _height = _setting('text.height', 1.9);
    _width = _setting('text.width', 720);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _appState.addListener(_onAppChanged);
    _joinLink(widget.link);
    _load();
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

  void _togglePageDark() {
    if (_paper == PagePaper.dark || _paper == PagePaper.black) {
      _setPaper(_paperBeforeDark ?? PagePaper.original);
    } else {
      _paperBeforeDark = _paper;
      _setPaper(PagePaper.dark);
    }
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// Opens a link outside the app: a web page, or a file such as a video.
  /// Links between the book's own chapters are left alone.
  Future<bool> _onTapUrl(String url) async {
    final path = url.split('#').first.toLowerCase();
    if (path.isEmpty || RegExp(r'\.x?html?$').hasMatch(path)) return false;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).linkFailed(url);
    if (!await openBookLink(_library, widget.book, url)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
    return true;
  }

  @override
  void didUpdateWidget(TextReaderScreen old) {
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

  void _onScroll() {
    _scheduleSave();
    if (_following || _pendingFraction != null) return;
    final position = linkedPosition;
    if (position != null) widget.link?.moved(this, position);
  }

  @override
  double? get linkedPosition => _book == null ? null : _section + _fraction;

  @override
  double follow(double position) {
    final count = _book?.sections.length ?? 0;
    if (count == 0) return position;
    final at = position.clamp(0.0, count.toDouble());
    final index = at.floor().clamp(0, count - 1);
    final fraction = at - index;
    _following = true;
    try {
      if (index != _section) {
        _goToSection(index, fraction: fraction);
      } else if (_scroll.hasClients) {
        _scroll.jumpTo(fraction * _scroll.position.maxScrollExtent);
      }
    } finally {
      _following = false;
    }
    return index + fraction;
  }

  double _setting(String key, double fallback) =>
      double.tryParse(_library.setting(key) ?? '') ?? fallback;

  Future<void> _load() async {
    try {
      final book = await loadTextBook(
        _library.fileOf(widget.book),
        widget.book.format,
      );
      if (!mounted) return;
      setState(() {
        _book = book;
        _section = _section.clamp(0, book.sections.length - 1);
      });
      _library.markOpened(widget.book.id, pageCount: book.sections.length);
      _restoreScroll();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.removeListener(_onAppChanged);
    _leaveLink(widget.link);
    _flush();
    _scroll.dispose();
    _keys.dispose();
    _selected.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flush();
  }

  double get _fraction {
    if (!_scroll.hasClients) return _pendingFraction ?? 0;
    final max = _scroll.position.maxScrollExtent;
    return max <= 0 ? 0 : (_scroll.offset / max).clamp(0.0, 1.0);
  }

  /// Jumps to the pending fraction after layout. Images that load later can
  /// lengthen the section, so the spot is approximate in picture-heavy books.
  void _restoreScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final fraction = _pendingFraction ?? 0;
      _pendingFraction = null;
      _scroll.jumpTo(fraction * _scroll.position.maxScrollExtent);
      _scheduleSave();
    });
  }

  void _scheduleSave() {
    if (_book == null || _pendingFraction != null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_book == null) return;
    _library.saveReadingState(
      widget.book.id,
      ReadingState(
        page: _section + 1,
        fy: _fraction,
        tint: PageTint(paper: _paper),
      ),
    );
  }

  void _goToSection(int index, {double fraction = 0}) {
    final count = _book?.sections.length ?? 0;
    if (index < 0 || index >= count) return;
    setState(() {
      _section = index;
      _pendingFraction = fraction;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _restoreScroll();
  }

  void _setType({double? size, double? height, double? width}) {
    final fraction = _fraction;
    setState(() {
      _size = size ?? _size;
      _height = height ?? _height;
      _width = width ?? _width;
      // Reflowing moves everything, so hold on to the relative spot.
      _pendingFraction = fraction;
    });
    _library.setSetting('text.size', '$_size');
    _library.setSetting('text.height', '$_height');
    _library.setSetting('text.width', '$_width');
    _restoreScroll();
  }

  void _setPaper(PagePaper paper) {
    setState(() => _paper = paper);
    _scheduleSave();
  }

  String _sectionTitle(AppLocalizations l, int index) {
    final title = _book!.sections[index].title;
    return title.isEmpty ? l.sectionN(localNumber(context, index + 1)) : title;
  }

  Future<void> _showContents() async {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final book = _book!;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Text(l.contents, style: theme.textTheme.titleMedium),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: book.sections.length,
                  itemBuilder: (context, i) => Material(
                    color: i == _section
                        ? MacColors.of(context).selection
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, i),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Text(
                          _sectionTitle(l, i),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _goToSection(picked);
  }

  void _showTextSettings() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Dialog(
        alignment: AlignmentDirectional.topEnd,
        insetPadding: const EdgeInsets.only(top: 58, left: 12, right: 12),
        child: SizedBox(
          width: 360,
          child: StatefulBuilder(
            builder: (context, rebuild) {
              final l = AppLocalizations.of(context);
              final theme = Theme.of(context);
              Widget slider(
                String label,
                double value,
                double min,
                double max,
                ValueChanged<double> onChanged,
              ) => Row(
                children: [
                  SizedBox(width: 92, child: Text(label)),
                  Expanded(
                    child: Semantics(
                      label: label,
                      child: CupertinoSlider(
                        min: min,
                        max: max,
                        value: value.clamp(min, max),
                        onChanged: (v) {
                          onChanged(v);
                          rebuild(() {});
                        },
                      ),
                    ),
                  ),
                ],
              );
              return Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Text(l.textSettings, style: theme.textTheme.titleMedium),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final paper in PagePaper.values)
                          InkWell(
                            onTap: () {
                              _setPaper(paper);
                              rebuild(() {});
                            },
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _paperColor(theme, paper),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: paper == _paper
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                  width: paper == _paper ? 3 : 1,
                                ),
                              ),
                              child: Text(
                                'Aa',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _inkColor(theme, paper),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    slider(
                      l.fontSize,
                      _size,
                      13,
                      28,
                      (v) => _setType(size: v.roundToDouble()),
                    ),
                    slider(
                      l.lineSpacing,
                      _height,
                      1.3,
                      2.6,
                      (v) => _setType(height: (v * 10).round() / 10),
                    ),
                    slider(
                      l.columnWidth,
                      _width,
                      420,
                      1100,
                      (v) => _setType(width: (v / 20).round() * 20),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // The "original" paper follows the app's own look.
  Color _paperColor(ThemeData theme, PagePaper paper) =>
      paper == PagePaper.original
      ? theme.colorScheme.surface
      : PageTint(paper: paper).paperColor;

  Color _inkColor(ThemeData theme, PagePaper paper) =>
      paper == PagePaper.original
      ? theme.colorScheme.onSurface
      : PageTint(paper: paper).inkColor;

  void _onWheel(PointerSignalEvent signal) {
    if (signal is! PointerScrollEvent) return;
    final speed = AppScope.read(context).scrollSpeed;
    GestureBinding.instance.pointerSignalResolver.register(signal, (event) {
      if (!_scroll.hasClients) return;
      final delta = (event as PointerScrollEvent).scrollDelta.dy * speed;
      _scroll.jumpTo(
        (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _focus) {
      setState(() => _focus = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Buttons for the desk the book is on: as buttons where there is room,
  /// otherwise in a menu.
  List<Widget> _deskActions(AppLocalizations l, ThemeData theme) {
    final actions = [
      if (widget.onOpenBeside != null)
        (
          CupertinoIcons.square_split_2x1,
          l.openBeside,
          widget.onOpenBeside!,
          false,
        ),
      if (widget.onNewWindow != null)
        (
          CupertinoIcons.macwindow,
          l.moveToNewWindow,
          widget.onNewWindow!,
          false,
        ),
      if (widget.link case final link?)
        (CupertinoIcons.link, l.scrollTogether, link.toggle, link.isOn),
    ];
    if (actions.isEmpty) return const [];
    if (MediaQuery.sizeOf(context).width >= _fullToolbar) {
      return [
        for (final (icon, label, action, active) in actions)
          MacIconButton(
            icon: icon,
            tooltip: label,
            active: active,
            onPressed: action,
          ),
      ];
    }
    return [
      PopupMenuButton<VoidCallback>(
        tooltip: l.moreActions,
        position: PopupMenuPosition.under,
        icon: const Icon(CupertinoIcons.ellipsis),
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          for (final (icon, label, action, active) in actions)
            PopupMenuItem(
              value: action,
              height: 38,
              child: Row(
                spacing: 10,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? theme.colorScheme.primary : null,
                  ),
                  Flexible(child: Text(label)),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final book = _book;
    final paper = _paperColor(theme, _paper);
    final ink = _inkColor(theme, _paper);
    final count = book?.sections.length ?? 0;

    final Widget body;
    if (_failed) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _library.fileOf(widget.book).existsSync()
                ? l.bookUnreadable
                : l.bookFileMissing,
            textAlign: TextAlign.center,
            style: TextStyle(color: ink),
          ),
        ),
      );
    } else if (book == null) {
      body = const Center(child: CupertinoActivityIndicator());
    } else {
      final section = book.sections[_section];
      body = Directionality(
        textDirection: book.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: SelectionArea(
          onSelectionChanged: (content) =>
              _selected.value = content?.plainText.trim() ?? '',
          contextMenuBuilder: (context, region) =>
              AdaptiveTextSelectionToolbar.buttonItems(
                anchors: region.contextMenuAnchors,
                buttonItems: [
                  ...region.contextMenuButtonItems,
                  if (_selected.value.isNotEmpty)
                    ContextMenuButtonItem(
                      label: l.translate,
                      onPressed: () {
                        region.hideToolbar();
                        showTranslation(context, _selected.value);
                      },
                    ),
                ],
              ),
          child: SingleChildScrollView(
            controller: _scroll,
            // Under bars that float, the text starts and ends clear of them.
            padding: EdgeInsets.fromLTRB(
              24,
              _autoHide && !_focus ? 32 + MacToolbar.height : 32,
              24,
              _autoHide && !_focus ? 32 + 38 : 32,
            ),
            // Sits inside the scroll view so it gets the wheel first and
            // can apply the chosen scroll speed.
            child: Listener(
              onPointerSignal: _onWheel,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _width),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HtmlWidget(
                        section.html,
                        key: ValueKey(_section),
                        textStyle: TextStyle(
                          fontSize: _size,
                          height: _height,
                          color: ink,
                        ),
                        onTapUrl: _onTapUrl,
                        customStylesBuilder: (element) =>
                            element.localName == 'a'
                            ? {'text-decoration': 'none'}
                            : null,
                        customWidgetBuilder: (element) {
                          if (element.localName != 'img') return null;
                          final src = element.attributes['src'];
                          final bytes = src == null
                              ? null
                              : book.image(section, src);
                          // Pictures outside the book aren't fetched.
                          if (bytes == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Image.memory(
                              bytes,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          );
                        },
                      ),
                      if (_section < count - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () => _goToSection(_section + 1),
                              child: Text(_sectionTitle(l, _section + 1)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final toolbar = _focus
        ? null
        : MacToolbar(
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
                icon: CupertinoIcons.list_bullet,
                tooltip: l.contents,
                onPressed: book == null || count < 2 ? null : _showContents,
              ),
              ValueListenableBuilder(
                valueListenable: _selected,
                builder: (context, selected, _) => MacIconButton(
                  icon: CupertinoIcons.globe,
                  tooltip: selected.isEmpty ? l.translateHint : l.translate,
                  onPressed: selected.isEmpty
                      ? null
                      : () => showTranslation(context, selected),
                ),
              ),
              MacIconButton(
                icon: CupertinoIcons.textformat_size,
                tooltip: l.textSettings,
                onPressed: _showTextSettings,
              ),
              MacIconButton(
                icon: CupertinoIcons.fullscreen,
                tooltip: withShortcut(l.focusMode, AppKeys.focusMode),
                onPressed: () => setState(() => _focus = true),
              ),
              ..._deskActions(l, theme),
            ],
          );
    final page = Stack(
      children: [
        Positioned.fill(child: SafeArea(child: body)),
        if (_focus)
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
    );
    final sectionBar = _focus || book == null || count < 2
        ? null
        : Container(
            decoration: BoxDecoration(
              color: MacColors.of(context).toolbar,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 38,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    MacIconButton(
                      icon: CupertinoIcons.chevron_back,
                      tooltip: l.previousSection,
                      onPressed: _section > 0
                          ? () => _goToSection(_section - 1)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        l.sectionOf(
                          localNumber(context, _section + 1),
                          localNumber(context, count),
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    MacIconButton(
                      icon: CupertinoIcons.chevron_forward,
                      tooltip: l.nextSection,
                      onPressed: _section < count - 1
                          ? () => _goToSection(_section + 1)
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          );

    return CallbackShortcuts(
      bindings: {
        AppKeys.focusMode: () => setState(() => _focus = !_focus),
        AppKeys.pageDark: _togglePageDark,
        AppKeys.autoHide: _toggleAutoHide,
        AppKeys.closeBook: _close,
      },
      child: Focus(
        focusNode: _keys,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: paper,
          appBar: _autoHide ? null : toolbar,
          body: _autoHide && toolbar != null
              ? AutoHideBars(top: toolbar, body: page, bottom: sectionBar)
              : page,
          bottomNavigationBar: _autoHide ? null : sectionBar,
        ),
      ),
    );
  }
}

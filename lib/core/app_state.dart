import 'package:flutter/widgets.dart';

import '../data/library.dart';
import '../data/models.dart';
import '../sync/sync_controller.dart';
import 'theme.dart';

export 'calendar.dart';

enum AppTab { library, notes, notebooks, tasks, search, settings }

/// App-wide state: look, language, current section and the list of books.
class AppState extends ChangeNotifier {
  AppState(this.library) {
    _look =
        AppLook.values.asNameMap()[library.setting('ui.look')] ?? AppLook.paper;
    _localeCode = library.setting('ui.locale');
    _accent =
        AppAccent.values.asNameMap()[library.setting('ui.accent')] ??
        AppAccent.blue;
    _tab = AppTab.values.asNameMap()[library.setting('ui.tab')] ?? _tab;
    _books = library.books();
    _scrollSpeed =
        double.tryParse(library.setting('reader.scrollSpeed') ?? '') ?? 1;
    _smoothScroll = library.setting('reader.smoothScroll') != '0';
    sync = SyncController(library, onMerged: _reloadAfterSync);
  }

  final Library library;
  late final SyncController sync;

  /// Fires only when the look, accent or language changes, so the app's
  /// root (theme and locale) can rebuild for those and nothing else.
  final appearance = ValueNotifier<int>(0);

  /// What is typed in the search section; kept here so it survives leaving
  /// the section and coming back.
  String searchQuery = '';

  late double _scrollSpeed;
  late bool _smoothScroll;

  /// How far one notch of the mouse wheel moves a page, as a multiple of
  /// the normal step.
  double get scrollSpeed => _scrollSpeed;
  set scrollSpeed(double value) {
    if (value == _scrollSpeed) return;
    _scrollSpeed = value;
    library.setSetting('reader.scrollSpeed', '$value');
    notifyListeners();
  }

  /// Whether the PDF page glides to a stop after the wheel or a flick,
  /// rather than jumping step by step.
  bool get smoothScroll => _smoothScroll;
  set smoothScroll(bool value) {
    if (value == _smoothScroll) return;
    _smoothScroll = value;
    library.setSetting('reader.smoothScroll', value ? '1' : '0');
    notifyListeners();
  }

  late AppLook _look;
  late AppAccent _accent;
  var _tab = AppTab.library;
  String? _openNoteId;
  String? _localeCode;
  late List<Book> _books;

  AppLook get look => _look;
  set look(AppLook value) {
    if (value == _look) return;
    _look = value;
    library.setSetting('ui.look', value.name);
    appearance.value++;
    notifyListeners();
  }

  AppAccent get accent => _accent;
  set accent(AppAccent value) {
    if (value == _accent) return;
    _accent = value;
    library.setSetting('ui.accent', value.name);
    appearance.value++;
    notifyListeners();
  }

  /// Section showing in the main window; remembered across launches.
  AppTab get tab => _tab;
  set tab(AppTab value) {
    if (value == _tab) return;
    _tab = value;
    library.setSetting('ui.tab', value.name);
    notifyListeners();
  }

  /// Note selected in the notes section.
  String? get openNoteId => _openNoteId;
  set openNoteId(String? id) {
    if (id == _openNoteId) return;
    _openNoteId = id;
    notifyListeners();
  }

  /// Switches to the notes section with [id] selected.
  void showNote(String id) {
    _tab = AppTab.notes;
    library.setSetting('ui.tab', _tab.name);
    _openNoteId = id;
    notifyListeners();
  }

  /// Null follows the system language.
  String? get localeCode => _localeCode;
  set localeCode(String? value) {
    if (value == _localeCode) return;
    _localeCode = value;
    library.setSetting('ui.locale', value);
    appearance.value++;
    notifyListeners();
  }

  List<Book> get books => _books;

  /// Rebuilds everything that reads notes or highlights from the library.
  void refresh() {
    notifyListeners();
    sync.schedule();
  }

  void reloadBooks() {
    _books = library.books();
    notifyListeners();
    sync.schedule();
  }

  void _reloadAfterSync() {
    _books = library.books();
    notifyListeners();
  }

  /// Book that was open when the app last closed, so launch can reopen it.
  String? get sessionBookId => library.setting('session.book');
  set sessionBookId(String? id) => library.setSetting('session.book', id);
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks that must not subscribe to rebuilds.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

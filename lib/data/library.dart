import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/calendar.dart';
import '../draw/mark.dart';
import '../reader/page_tint.dart';
import 'models.dart';

String newId() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// Folds spelling variants so a search matches however the text was typed:
/// Arabic yeh and kaf become their Persian forms and the zero-width
/// non-joiner is dropped.
String normalizeForSearch(String text) => text
    .replaceAll('\u064A', '\u06CC')
    .replaceAll('\u0643', '\u06A9')
    .replaceAll('\u200C', '')
    .toLowerCase();

/// The first date after [today] that a repeating task falls on, counting
/// from its current [dueDay] so the rhythm (every Saturday, the 5th of each
/// month) is kept even when it is finished late.
int nextDueDay(int dueDay, TaskRepeat repeat, {required int today}) {
  var next = dueDay;
  do {
    switch (repeat) {
      case TaskRepeat.none:
        return dueDay;
      case TaskRepeat.daily:
        next += 1;
      case TaskRepeat.weekly:
        next += 7;
      case TaskRepeat.monthly:
        final date = dateOfDay(next);
        final lastOfNext = DateTime(date.year, date.month + 2, 0).day;
        final wanted = dateOfDay(dueDay).day;
        next = dayOf(
          DateTime(
            date.year,
            date.month + 1,
            wanted > lastOfNext ? lastOfNext : wanted,
          ),
        );
    }
  } while (next <= today);
  return next;
}

/// Books, reading positions, highlights, notes, tasks and settings stored on
/// this device.
class Library {
  /// [clock] supplies the edit timestamps (ms since epoch) that decide
  /// which copy of a row wins in a sync; tests pass a fake one.
  Library(this.db, this.rootDir, {int Function()? clock})
    : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    deviceId = setting('device.id') ?? newId();
    setSetting('device.id', deviceId);
    _indexMissingBooks();
    _registerDevice();
  }

  /// Name other devices show for this one.
  String get deviceName =>
      db.select('SELECT name FROM devices WHERE id = ?', [
            deviceId,
          ]).firstOrNull?['name']
          as String? ??
      '';

  void _registerDevice() {
    if (deviceName.isNotEmpty) return;
    String name;
    try {
      name = Platform.localHostname;
    } catch (_) {
      name = Platform.operatingSystem;
    }
    db.execute(
      'INSERT OR REPLACE INTO devices (id, name, updated_at) VALUES (?, ?, ?)',
      [deviceId, name, _now],
    );
  }

  /// Books added before search existed aren't in the index yet.
  void _indexMissingBooks() {
    final rows = db.select(
      'SELECT id, title FROM books WHERE deleted = 0 AND id NOT IN '
      "(SELECT ref FROM search_index WHERE kind = 'book')",
    );
    for (final row in rows) {
      _index('book', row['id'] as String, row['title'] as String);
    }
  }

  final Database db;

  /// Folder holding `books/` and `covers/`.
  final String rootDir;

  late final String deviceId;

  String get booksDir => p.join(rootDir, 'books');
  String get coversDir => p.join(rootDir, 'covers');

  File fileOf(Book book) => File(p.join(booksDir, book.fileName));
  File coverOf(String bookId) => File(p.join(coversDir, '$bookId.png'));

  final int Function() _clock;

  int get _now => _clock();

  // Settings

  String? setting(String key) {
    final rows = db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setSetting(String key, String? value) {
    if (value == null) {
      db.execute('DELETE FROM settings WHERE key = ?', [key]);
    } else {
      db.execute(
        'INSERT INTO settings (key, value) VALUES (?, ?) '
        'ON CONFLICT (key) DO UPDATE SET value = excluded.value',
        [key, value],
      );
    }
  }

  // Books

  /// Most recently opened first, then most recently added.
  List<Book> books() {
    final rows = db.select(
      'SELECT b.*, r.page AS last_page, r.fy AS last_fy FROM books b '
      'LEFT JOIN reading_state r ON r.book_id = b.id AND r.device_id = ? '
      'WHERE b.deleted = 0 '
      'ORDER BY COALESCE(b.opened_at, b.added_at) DESC',
      [deviceId],
    );
    return [for (final row in rows) _book(row)];
  }

  Book? book(String id) {
    final rows = db.select(
      'SELECT b.*, r.page AS last_page, r.fy AS last_fy FROM books b '
      'LEFT JOIN reading_state r ON r.book_id = b.id AND r.device_id = ? '
      'WHERE b.id = ? AND b.deleted = 0',
      [deviceId, id],
    );
    return rows.isEmpty ? null : _book(rows.first);
  }

  Book? bookBySha256(String sha256) {
    final rows = db.select(
      'SELECT id FROM books WHERE sha256 = ? AND deleted = 0',
      [sha256],
    );
    return rows.isEmpty ? null : book(rows.first['id'] as String);
  }

  Book addBook({
    required String id,
    required String title,
    required String format,
    required String fileName,
    required String sha256,
    required int size,
    required int pageCount,
  }) {
    final now = _now;
    // Ids are derived from the file's hash, so adding a book again after
    // removing it revives the same row.
    db.execute(
      'INSERT INTO books (id, title, format, file_name, sha256, size, '
      'page_count, added_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT (id) DO UPDATE SET title = excluded.title, deleted = 0, '
      'added_at = excluded.added_at, updated_at = excluded.updated_at',
      [id, title, format, fileName, sha256, size, pageCount, now, now],
    );
    _index('book', id, title);
    return book(id)!;
  }

  void markOpened(String id, {int? pageCount}) {
    final now = _now;
    db.execute(
      'UPDATE books SET opened_at = ?, updated_at = ?, '
      'page_count = COALESCE(?, page_count) WHERE id = ?',
      [now, now, pageCount, id],
    );
  }

  /// Leaves a tombstone row so a later sync can propagate the removal, and
  /// deletes the app's own copy of the file.
  void removeBook(Book book) {
    db.execute('UPDATE books SET deleted = 1, updated_at = ? WHERE id = ?', [
      _now,
      book.id,
    ]);
    db.execute('DELETE FROM reading_state WHERE book_id = ?', [book.id]);
    for (final annotation in annotations(book.id)) {
      _unindex('annotation', annotation.id);
    }
    db.execute(
      'UPDATE annotations SET deleted = 1, updated_at = ? WHERE book_id = ?',
      [_now, book.id],
    );
    _unindex('book', book.id);
    for (final file in [fileOf(book), coverOf(book.id)]) {
      if (file.existsSync()) file.deleteSync();
    }
  }

  // Reading position

  ReadingState? readingState(String bookId) {
    final rows = db.select(
      'SELECT * FROM reading_state WHERE book_id = ? AND device_id = ?',
      [bookId, deviceId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final tint = row['tint'] as String?;
    return ReadingState(
      page: row['page'] as int,
      fx: row['fx'] as double,
      fy: row['fy'] as double,
      zoomRel: row['zoom_rel'] as double,
      tint: tint == null
          ? const PageTint()
          : PageTint.fromJson(jsonDecode(tint) as Map<String, Object?>),
    );
  }

  /// The latest position another device saved for this book, when it is
  /// newer than this device's own and on a different page.
  ({ReadingState state, String device})? newerPositionElsewhere(String bookId) {
    final own = db.select(
      'SELECT page, updated_at FROM reading_state '
      'WHERE book_id = ? AND device_id = ?',
      [bookId, deviceId],
    ).firstOrNull;
    final rows = db.select(
      'SELECT r.*, d.name AS device_name FROM reading_state r '
      'LEFT JOIN devices d ON d.id = r.device_id '
      'WHERE r.book_id = ? AND r.device_id != ? '
      'ORDER BY r.updated_at DESC LIMIT 1',
      [bookId, deviceId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if (own != null &&
        ((own['updated_at'] as int) >= (row['updated_at'] as int) ||
            own['page'] == row['page'])) {
      return null;
    }
    return (
      state: ReadingState(
        page: row['page'] as int,
        fx: row['fx'] as double,
        fy: row['fy'] as double,
        zoomRel: row['zoom_rel'] as double,
      ),
      device: row['device_name'] as String? ?? '',
    );
  }

  void saveReadingState(String bookId, ReadingState state) {
    db.execute(
      'INSERT INTO reading_state '
      '(book_id, device_id, page, fx, fy, zoom_rel, tint, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT (book_id, device_id) DO UPDATE SET page = excluded.page, '
      'fx = excluded.fx, fy = excluded.fy, zoom_rel = excluded.zoom_rel, '
      'tint = excluded.tint, updated_at = excluded.updated_at',
      [
        bookId,
        deviceId,
        state.page,
        state.fx,
        state.fy,
        state.zoomRel,
        jsonEncode(state.tint.toJson()),
        _now,
      ],
    );
  }

  // Highlights

  List<Annotation> annotations(String bookId) {
    final rows = db.select(
      'SELECT * FROM annotations WHERE book_id = ? AND deleted = 0 '
      'ORDER BY page, created_at',
      [bookId],
    );
    return [for (final row in rows) _annotation(row)];
  }

  Annotation? annotation(String id) {
    final rows = db.select(
      'SELECT * FROM annotations WHERE id = ? AND deleted = 0',
      [id],
    );
    return rows.isEmpty ? null : _annotation(rows.first);
  }

  Annotation addHighlight({
    required String bookId,
    required int page,
    required HighlightColor color,
    required List<double> rects,
    required String text,
  }) {
    final id = newId();
    final now = _now;
    db.execute(
      'INSERT INTO annotations (id, book_id, page, kind, color, rects, text, '
      "created_at, updated_at) VALUES (?, ?, ?, 'highlight', ?, ?, ?, ?, ?)",
      [id, bookId, page, color.name, jsonEncode(rects), text, now, now],
    );
    _index('annotation', id, text);
    return annotation(id)!;
  }

  /// Stores something drawn on a page; the mark's points are in PDF space.
  Annotation addInk({
    required String bookId,
    required int page,
    required Mark mark,
  }) => _addPlaced(
    bookId: bookId,
    page: page,
    kind: AnnotationKind.ink,
    at: mark.points,
    style: jsonEncode(mark.toJson()),
    text: mark.text,
  );

  /// Sticks a note on a page with its corner at PDF-space ([x], [y]).
  Annotation addSticky({
    required String bookId,
    required int page,
    required double x,
    required double y,
    required HighlightColor color,
  }) => _addPlaced(
    bookId: bookId,
    page: page,
    kind: AnnotationKind.sticky,
    at: [x, y],
    color: color,
  );

  /// Attaches the notebook page [pageId] to a spot on a book's page.
  Annotation addPageLink({
    required String bookId,
    required int page,
    required double x,
    required double y,
    required String pageId,
  }) => _addPlaced(
    bookId: bookId,
    page: page,
    kind: AnnotationKind.page,
    at: [x, y],
    text: pageId,
  );

  Annotation _addPlaced({
    required String bookId,
    required int page,
    required AnnotationKind kind,
    required List<double> at,
    HighlightColor color = HighlightColor.yellow,
    String style = '',
    String text = '',
  }) {
    final id = newId();
    final now = _now;
    db.execute(
      'INSERT INTO annotations (id, book_id, page, kind, color, rects, text, '
      'style, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        bookId,
        page,
        kind.name,
        color.name,
        jsonEncode(at),
        text,
        style,
        now,
        now,
      ],
    );
    if (text.isNotEmpty && kind == AnnotationKind.ink) {
      _index('annotation', id, text);
    }
    return annotation(id)!;
  }

  /// Moves a sticky note or attached page to PDF-space ([x], [y]).
  void moveAnnotation(String id, double x, double y) {
    db.execute(
      'UPDATE annotations SET rects = ?, updated_at = ? WHERE id = ?',
      [
        jsonEncode([x, y]),
        _now,
        id,
      ],
    );
  }

  /// Brings back an annotation that was removed, for undo.
  void restoreAnnotation(String id) {
    db.execute(
      'UPDATE annotations SET deleted = 0, updated_at = ? WHERE id = ?',
      [_now, id],
    );
    final restored = annotation(id);
    if (restored != null) {
      _index('annotation', id, '${restored.text}\n${restored.note}');
    }
  }

  // Notebooks

  List<Notebook> notebooks() {
    final rows = db.select(
      'SELECT n.*, (SELECT COUNT(*) FROM pages p WHERE p.notebook_id = n.id '
      'AND p.deleted = 0) AS page_count FROM notebooks n '
      'WHERE n.deleted = 0 ORDER BY n.updated_at DESC',
    );
    return [for (final row in rows) _notebook(row)];
  }

  Notebook? notebook(String id) {
    final rows = db.select(
      'SELECT n.*, (SELECT COUNT(*) FROM pages p WHERE p.notebook_id = n.id '
      'AND p.deleted = 0) AS page_count FROM notebooks n '
      'WHERE n.id = ? AND n.deleted = 0',
      [id],
    );
    return rows.isEmpty ? null : _notebook(rows.first);
  }

  Notebook addNotebook(String name, {String? bookId}) {
    final id = newId();
    final now = _now;
    db.execute(
      'INSERT INTO notebooks (id, name, book_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [id, name, bookId, now, now],
    );
    return notebook(id)!;
  }

  /// The notebook that holds pages attached to [book], made on first use.
  Notebook notebookFor(Book book) {
    final rows = db.select(
      'SELECT id FROM notebooks WHERE book_id = ? AND deleted = 0',
      [book.id],
    );
    return rows.isEmpty
        ? addNotebook(book.title, bookId: book.id)
        : notebook(rows.first['id'] as String)!;
  }

  void renameNotebook(String id, String name) {
    db.execute('UPDATE notebooks SET name = ?, updated_at = ? WHERE id = ?', [
      name,
      _now,
      id,
    ]);
  }

  void removeNotebook(String id) {
    final now = _now;
    db.execute(
      'UPDATE notebooks SET deleted = 1, updated_at = ? WHERE id = ?',
      [now, id],
    );
    db.execute(
      'UPDATE pages SET deleted = 1, updated_at = ? WHERE notebook_id = ?',
      [now, id],
    );
  }

  List<NotebookPage> pages(String notebookId) {
    final rows = db.select(
      'SELECT * FROM pages WHERE notebook_id = ? AND deleted = 0 '
      'ORDER BY position',
      [notebookId],
    );
    return [for (final row in rows) _page(row)];
  }

  NotebookPage? page(String id) {
    final rows = db.select('SELECT * FROM pages WHERE id = ? AND deleted = 0', [
      id,
    ]);
    return rows.isEmpty ? null : _page(rows.first);
  }

  /// Adds a sheet at the end of a notebook.
  NotebookPage addPage(
    String notebookId, {
    PaperStyle paper = PaperStyle.blank,
  }) {
    final id = newId();
    final now = _now;
    final last =
        db
                .select(
                  'SELECT MAX(position) FROM pages WHERE notebook_id = ? '
                  'AND deleted = 0',
                  [notebookId],
                )
                .first
                .columnAt(0)
            as num?;
    db.execute(
      'INSERT INTO pages (id, notebook_id, position, paper, created_at, '
      'updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [id, notebookId, (last ?? 0) + 1024, paper.name, now, now],
    );
    db.execute('UPDATE notebooks SET updated_at = ? WHERE id = ?', [
      now,
      notebookId,
    ]);
    return page(id)!;
  }

  void savePage(String id, {List<Mark>? marks, PaperStyle? paper}) {
    db.execute(
      'UPDATE pages SET content = COALESCE(?, content), '
      'paper = COALESCE(?, paper), updated_at = ? WHERE id = ?',
      [marks == null ? null : Mark.encodeAll(marks), paper?.name, _now, id],
    );
  }

  void removePage(String id) {
    db.execute('UPDATE pages SET deleted = 1, updated_at = ? WHERE id = ?', [
      _now,
      id,
    ]);
  }

  Notebook _notebook(Row row) => Notebook(
    id: row['id'] as String,
    name: row['name'] as String,
    bookId: row['book_id'] as String?,
    pageCount: row['page_count'] as int,
  );

  NotebookPage _page(Row row) => NotebookPage(
    id: row['id'] as String,
    notebookId: row['notebook_id'] as String,
    paper: PaperStyle.values.asNameMap()[row['paper']] ?? PaperStyle.blank,
    marks: Mark.decodeAll(row['content'] as String),
  );

  void updateAnnotation(String id, {HighlightColor? color, String? note}) {
    db.execute(
      'UPDATE annotations SET color = COALESCE(?, color), '
      'note = COALESCE(?, note), updated_at = ? WHERE id = ?',
      [color?.name, note, _now, id],
    );
    final updated = annotation(id);
    if (updated != null) {
      _index('annotation', id, '${updated.text}\n${updated.note}');
    }
  }

  void removeAnnotation(String id) {
    db.execute(
      'UPDATE annotations SET deleted = 1, updated_at = ? WHERE id = ?',
      [_now, id],
    );
    _unindex('annotation', id);
  }

  // Notes

  /// Most recently edited first.
  List<Note> notes() {
    final rows = db.select(
      'SELECT * FROM notes WHERE deleted = 0 ORDER BY updated_at DESC',
    );
    return [for (final row in rows) _note(row)];
  }

  Note? note(String id) {
    final rows = db.select('SELECT * FROM notes WHERE id = ? AND deleted = 0', [
      id,
    ]);
    return rows.isEmpty ? null : _note(rows.first);
  }

  Note addNote({String body = '', String? bookId}) {
    final id = newId();
    final now = _now;
    db.execute(
      'INSERT INTO notes (id, body, book_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [id, body, bookId, now, now],
    );
    _index('note', id, body);
    return note(id)!;
  }

  void updateNote(String id, String body) {
    db.execute('UPDATE notes SET body = ?, updated_at = ? WHERE id = ?', [
      body,
      _now,
      id,
    ]);
    _index('note', id, body);
  }

  void removeNote(String id) {
    db.execute('UPDATE notes SET deleted = 1, updated_at = ? WHERE id = ?', [
      _now,
      id,
    ]);
    _unindex('note', id);
  }

  // Projects and tasks

  List<Project> projects() {
    final rows = db.select(
      'SELECT id, name FROM projects WHERE deleted = 0 ORDER BY created_at',
    );
    return [
      for (final row in rows)
        Project(id: row['id'] as String, name: row['name'] as String),
    ];
  }

  /// Creates a project whose board starts with a column per [listNames].
  Project addProject(String name, {List<String> listNames = const []}) {
    final id = newId();
    final now = _now;
    db.execute(
      'INSERT INTO projects (id, name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?)',
      [id, name, now, now],
    );
    for (final listName in listNames) {
      addList(id, listName);
    }
    return Project(id: id, name: name);
  }

  void renameProject(String id, String name) {
    db.execute('UPDATE projects SET name = ?, updated_at = ? WHERE id = ?', [
      name,
      _now,
      id,
    ]);
  }

  /// Removes the project and leaves its tasks without one.
  void removeProject(String id) {
    final now = _now;
    db.execute('UPDATE projects SET deleted = 1, updated_at = ? WHERE id = ?', [
      now,
      id,
    ]);
    db.execute(
      'UPDATE tasks SET project_id = NULL, list_id = NULL, updated_at = ? '
      'WHERE project_id = ?',
      [now, id],
    );
    db.execute(
      'UPDATE lists SET deleted = 1, updated_at = ? WHERE project_id = ?',
      [now, id],
    );
  }

  // Board lists

  List<TaskList> lists(String projectId) {
    final rows = db.select(
      'SELECT id, name FROM lists WHERE project_id = ? AND deleted = 0 '
      'ORDER BY position',
      [projectId],
    );
    return [
      for (final row in rows)
        TaskList(id: row['id'] as String, name: row['name'] as String),
    ];
  }

  TaskList addList(String projectId, String name) {
    final id = newId();
    final now = _now;
    final last =
        db
                .select(
                  'SELECT MAX(position) FROM lists WHERE project_id = ? '
                  'AND deleted = 0',
                  [projectId],
                )
                .first
                .columnAt(0)
            as num?;
    db.execute(
      'INSERT INTO lists (id, project_id, name, position, created_at, '
      'updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [id, projectId, name, (last ?? 0) + 1024, now, now],
    );
    return TaskList(id: id, name: name);
  }

  void renameList(String id, String name) {
    db.execute('UPDATE lists SET name = ?, updated_at = ? WHERE id = ?', [
      name,
      _now,
      id,
    ]);
  }

  /// Removes a column; its cards move to the end of the project's first
  /// remaining column so nothing is lost.
  void removeList(String id) {
    final rows = db.select('SELECT project_id FROM lists WHERE id = ?', [id]);
    if (rows.isEmpty) return;
    final projectId = rows.first['project_id'] as String;
    db.execute('UPDATE lists SET deleted = 1, updated_at = ? WHERE id = ?', [
      _now,
      id,
    ]);
    final target = lists(projectId).firstOrNull?.id;
    final orphans = db.select(
      'SELECT id FROM tasks WHERE list_id = ? AND deleted = 0 '
      'ORDER BY position',
      [id],
    );
    for (final row in orphans) {
      moveTask(row['id'] as String, listId: target);
    }
  }

  /// Gives a project made before boards had lists its columns, sorting its
  /// cards into them by their old status. Does nothing if it has columns.
  void ensureLists(String projectId, List<String> names) {
    if (names.length < 3 || lists(projectId).isNotEmpty) return;
    final created = [for (final name in names) addList(projectId, name)];
    final rows = db.select(
      'SELECT id, status FROM tasks WHERE project_id = ? AND deleted = 0 '
      'AND parent_id IS NULL ORDER BY position',
      [projectId],
    );
    for (final row in rows) {
      final list = switch (row['status']) {
        'doing' => created[1],
        'done' => created.last,
        _ => created.first,
      };
      moveTask(row['id'] as String, listId: list.id);
    }
    db.execute(
      "UPDATE tasks SET status = 'todo' WHERE project_id = ? "
      "AND status = 'doing'",
      [projectId],
    );
  }

  /// Puts a card into [listId] just above [beforeTaskId], or at the end of
  /// the list when that is null.
  void moveTask(String id, {required String? listId, String? beforeTaskId}) {
    final siblings = db.select(
      'SELECT id, position FROM tasks WHERE list_id IS ? AND deleted = 0 '
      'AND parent_id IS NULL AND id != ? ORDER BY position',
      [listId, id],
    );
    final index = beforeTaskId == null
        ? -1
        : siblings.indexWhere((row) => row['id'] == beforeTaskId);
    final double position;
    if (siblings.isEmpty) {
      position = 1024;
    } else if (index < 0) {
      position = (siblings.last['position'] as num) + 1024;
    } else {
      final next = (siblings[index]['position'] as num).toDouble();
      final previous = index == 0
          ? next - 2048
          : (siblings[index - 1]['position'] as num).toDouble();
      position = (previous + next) / 2;
    }
    db.execute(
      'UPDATE tasks SET list_id = ?, position = ?, updated_at = ? '
      'WHERE id = ?',
      [listId, position, _now, id],
    );
  }

  /// Cards of a project's board by column id, each column in card order.
  /// Finished cards stay on the board, as in Trello.
  Map<String, List<Task>> board(String projectId) {
    final rows = db.select(
      'SELECT $_taskColumns FROM tasks t WHERE t.deleted = 0 '
      'AND t.parent_id IS NULL AND t.project_id = ? ORDER BY t.position',
      [projectId],
    );
    final byList = <String, List<Task>>{};
    for (final row in rows) {
      final task = _task(row);
      if (task.listId != null) (byList[task.listId!] ??= []).add(task);
    }
    return byList;
  }

  void setTaskLabels(String id, Set<TaskLabel> labels) {
    db.execute('UPDATE tasks SET labels = ?, updated_at = ? WHERE id = ?', [
      labels.map((l) => l.name).join(','),
      _now,
      id,
    ]);
  }

  static const _taskColumns =
      't.*, '
      '(SELECT COUNT(*) FROM tasks s WHERE s.parent_id = t.id AND '
      's.deleted = 0) AS subtask_count, '
      '(SELECT COUNT(*) FROM tasks s WHERE s.parent_id = t.id AND '
      "s.deleted = 0 AND s.status = 'done') AS subtasks_done";

  /// Top-level tasks: open ones first by due date then priority, then
  /// finished ones with the most recently finished first.
  List<Task> tasks() {
    final rows = db.select(
      'SELECT $_taskColumns FROM tasks t '
      'WHERE t.deleted = 0 AND t.parent_id IS NULL '
      "ORDER BY t.status = 'done', "
      "CASE WHEN t.status = 'done' THEN -t.done_at END, "
      't.due_day IS NULL, t.due_day, t.priority DESC, t.created_at',
    );
    return [for (final row in rows) _task(row)];
  }

  List<Task> subtasks(String parentId) {
    final rows = db.select(
      'SELECT $_taskColumns FROM tasks t '
      'WHERE t.deleted = 0 AND t.parent_id = ? ORDER BY t.created_at',
      [parentId],
    );
    return [for (final row in rows) _task(row)];
  }

  Task? task(String id) {
    final rows = db.select(
      'SELECT $_taskColumns FROM tasks t WHERE t.id = ? AND t.deleted = 0',
      [id],
    );
    return rows.isEmpty ? null : _task(rows.first);
  }

  Task addTask({
    required String title,
    String? projectId,
    String? listId,
    String? parentId,
    int? dueDay,
    int priority = 0,
    TaskStatus status = TaskStatus.todo,
    String? sourceKind,
    String? sourceId,
  }) {
    final id = newId();
    final now = _now;
    // A card added to a project without naming a column joins its first.
    if (projectId != null && parentId == null) {
      listId ??= lists(projectId).firstOrNull?.id;
    }
    db.execute(
      'INSERT INTO tasks (id, title, project_id, parent_id, due_day, '
      'priority, status, source_kind, source_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        title,
        projectId,
        parentId,
        dueDay,
        priority,
        status.name,
        sourceKind,
        sourceId,
        now,
        now,
      ],
    );
    if (parentId == null) {
      _index('task', id, title);
      if (listId != null) moveTask(id, listId: listId);
    }
    return task(id)!;
  }

  void updateTask(
    String id, {
    String? title,
    String? notes,
    int? priority,
    TaskRepeat? repeat,
  }) {
    db.execute(
      'UPDATE tasks SET title = COALESCE(?, title), '
      'notes = COALESCE(?, notes), priority = COALESCE(?, priority), '
      'repeat = COALESCE(?, repeat), updated_at = ? WHERE id = ?',
      [title, notes, priority, repeat?.name, _now, id],
    );
    final updated = task(id);
    if (updated != null && updated.parentId == null) {
      _index('task', id, '${updated.title}\n${updated.notes}');
    }
  }

  void setTaskDue(String id, int? dueDay) {
    db.execute('UPDATE tasks SET due_day = ?, updated_at = ? WHERE id = ?', [
      dueDay,
      _now,
      id,
    ]);
  }

  /// Moves a task to another project (or to none), landing at the end of
  /// that project's first column.
  void setTaskProject(String id, String? projectId) {
    db.execute('UPDATE tasks SET project_id = ?, updated_at = ? WHERE id = ?', [
      projectId,
      _now,
      id,
    ]);
    moveTask(
      id,
      listId: projectId == null ? null : lists(projectId).firstOrNull?.id,
    );
  }

  /// Moves a task between the board columns. Finishing a repeating task
  /// that has a due date moves it to its next date instead of closing it;
  /// [today] is the day it is being finished on.
  void setTaskStatus(String id, TaskStatus status, {required int today}) {
    final current = task(id);
    if (current == null) return;
    final now = _now;
    if (status == TaskStatus.done &&
        current.repeat != TaskRepeat.none &&
        current.dueDay != null) {
      db.execute(
        "UPDATE tasks SET due_day = ?, status = 'todo', updated_at = ? "
        'WHERE id = ?',
        [nextDueDay(current.dueDay!, current.repeat, today: today), now, id],
      );
      db.execute(
        "UPDATE tasks SET status = 'todo', done_at = NULL, updated_at = ? "
        'WHERE parent_id = ?',
        [now, id],
      );
      return;
    }
    db.execute(
      'UPDATE tasks SET status = ?, done_at = ?, updated_at = ? WHERE id = ?',
      [status.name, status == TaskStatus.done ? now : null, now, id],
    );
  }

  void removeTask(String id) {
    db.execute(
      'UPDATE tasks SET deleted = 1, updated_at = ? '
      'WHERE id = ? OR parent_id = ?',
      [_now, id, id],
    );
    _unindex('task', id);
  }

  /// Open top-level tasks due on [today] or earlier.
  int dueTaskCount(int today) =>
      db
              .select(
                'SELECT COUNT(*) FROM tasks WHERE deleted = 0 AND '
                "parent_id IS NULL AND status != 'done' AND due_day <= ?",
                [today],
              )
              .first
              .columnAt(0)
          as int;

  Task _task(Row row) => Task(
    id: row['id'] as String,
    title: row['title'] as String,
    notes: row['notes'] as String,
    projectId: row['project_id'] as String?,
    listId: row['list_id'] as String?,
    parentId: row['parent_id'] as String?,
    labels: {
      for (final name in (row['labels'] as String).split(','))
        ?TaskLabel.values.asNameMap()[name],
    },
    status: TaskStatus.values.asNameMap()[row['status']] ?? TaskStatus.todo,
    priority: row['priority'] as int,
    dueDay: row['due_day'] as int?,
    repeat: TaskRepeat.values.asNameMap()[row['repeat']] ?? TaskRepeat.none,
    sourceKind: row['source_kind'] as String?,
    sourceId: row['source_id'] as String?,
    subtaskCount: row['subtask_count'] as int,
    subtasksDone: row['subtasks_done'] as int,
  );

  // Sync

  /// Tables that travel between devices, parents before children, with
  /// their primary key columns.
  static const syncTables = <String, List<String>>{
    'books': ['id'],
    'devices': ['id'],
    'projects': ['id'],
    'lists': ['id'],
    'tasks': ['id'],
    'notes': ['id'],
    'notebooks': ['id'],
    'pages': ['id'],
    'annotations': ['id'],
    'reading_state': ['book_id', 'device_id'],
  };

  /// Every synced row, tombstones included, keyed by table.
  Map<String, List<Map<String, Object?>>> exportRows() => {
    for (final table in syncTables.keys)
      table: [
        for (final row in db.select('SELECT * FROM $table'))
          Map<String, Object?>.of(row),
      ],
  };

  /// Folds rows exported by another device into this one. For each row the
  /// copy edited most recently wins as a whole; rows only the other side
  /// has are added. Returns how many rows changed here.
  int mergeRows(Map<String, Object?> tables) {
    var changed = 0;
    db.execute('BEGIN');
    try {
      for (final MapEntry(key: table, value: keys) in syncTables.entries) {
        final incoming = tables[table];
        if (incoming is! List) continue;
        final known = {
          for (final row in db.select('PRAGMA table_info($table)'))
            row['name'] as String,
        };
        for (final raw in incoming) {
          if (raw is! Map) continue;
          final row = {
            for (final entry in raw.entries)
              if (known.contains(entry.key)) entry.key as String: entry.value,
          };
          final updatedAt = row['updated_at'];
          if (updatedAt is! int || keys.any((k) => row[k] == null)) continue;
          final local = db.select(
            'SELECT updated_at FROM $table WHERE '
            '${keys.map((k) => '$k = ?').join(' AND ')}',
            [for (final k in keys) row[k]],
          );
          if (local.isNotEmpty &&
              (local.first['updated_at'] as int) >= updatedAt) {
            continue;
          }
          final columns = row.keys.toList();
          // Only the columns the other device knows are written, so a
          // newer app's extra columns survive a sync with an older one.
          final assignments = columns
              .where((c) => !keys.contains(c))
              .map((c) => '$c = excluded.$c')
              .join(', ');
          try {
            db.execute(
              'INSERT INTO $table (${columns.join(', ')}) '
              'VALUES (${List.filled(columns.length, '?').join(', ')}) '
              'ON CONFLICT (${keys.join(', ')}) DO UPDATE SET $assignments',
              [for (final c in columns) row[c]],
            );
            changed++;
          } on SqliteException {
            // A row whose parent never arrived is skipped; it is offered
            // again on the next sync.
          }
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    if (changed > 0) {
      _rebuildSearchIndex();
      _removeFilesOfDeletedBooks();
    }
    return changed;
  }

  /// Books in the library with their file hashes, for syncing the files.
  List<({Book book, String sha256})> bookFiles() => [
    for (final row in db.select(
      'SELECT id, sha256 FROM books WHERE deleted = 0',
    ))
      (book: book(row['id'] as String)!, sha256: row['sha256'] as String),
  ];

  void _removeFilesOfDeletedBooks() {
    final rows = db.select('SELECT id, file_name FROM books WHERE deleted = 1');
    for (final row in rows) {
      for (final file in [
        File(p.join(booksDir, row['file_name'] as String)),
        coverOf(row['id'] as String),
      ]) {
        if (file.existsSync()) file.deleteSync();
      }
    }
  }

  void _rebuildSearchIndex() {
    db.execute('DELETE FROM search_index');
    for (final row in db.select(
      'SELECT id, title FROM books WHERE deleted = 0',
    )) {
      _index('book', row['id'] as String, row['title'] as String);
    }
    for (final row in db.select(
      'SELECT a.id, a.text, a.note FROM annotations a '
      'JOIN books b ON b.id = a.book_id '
      'WHERE a.deleted = 0 AND b.deleted = 0',
    )) {
      _index(
        'annotation',
        row['id'] as String,
        '${row['text']}\n${row['note']}',
      );
    }
    for (final row in db.select(
      'SELECT id, body FROM notes WHERE deleted = 0',
    )) {
      _index('note', row['id'] as String, row['body'] as String);
    }
    for (final row in db.select(
      'SELECT id, title, notes FROM tasks '
      'WHERE deleted = 0 AND parent_id IS NULL',
    )) {
      _index('task', row['id'] as String, '${row['title']}\n${row['notes']}');
    }
  }

  // Search

  /// Finds books by title and highlights and notes by their text. Every
  /// word of [query] must appear; the last one may be a prefix.
  List<SearchHit> search(String query, {int limit = 60}) {
    final words = normalizeForSearch(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '"${w.replaceAll('"', '""')}"*');
    if (words.isEmpty) return const [];
    final rows = db.select(
      'SELECT kind, ref FROM search_index WHERE search_index MATCH ? '
      'ORDER BY rank LIMIT ?',
      [words.join(' '), limit],
    );
    final hits = <SearchHit>[];
    for (final row in rows) {
      final ref = row['ref'] as String;
      switch (row['kind']) {
        case 'book':
          final found = book(ref);
          if (found != null) hits.add(SearchHit(book: found));
        case 'annotation':
          final found = annotation(ref);
          final owner = found == null ? null : book(found.bookId);
          if (owner != null) {
            hits.add(SearchHit(annotation: found, book: owner));
          }
        case 'note':
          final found = note(ref);
          if (found != null) hits.add(SearchHit(note: found));
        case 'task':
          final found = task(ref);
          if (found != null) hits.add(SearchHit(task: found));
      }
    }
    return hits;
  }

  void _index(String kind, String ref, String text) {
    _unindex(kind, ref);
    db.execute('INSERT INTO search_index (kind, ref, body) VALUES (?, ?, ?)', [
      kind,
      ref,
      normalizeForSearch(text),
    ]);
  }

  void _unindex(String kind, String ref) {
    db.execute('DELETE FROM search_index WHERE kind = ? AND ref = ?', [
      kind,
      ref,
    ]);
  }

  Annotation _annotation(Row row) => Annotation(
    id: row['id'] as String,
    kind:
        AnnotationKind.values.asNameMap()[row['kind']] ??
        AnnotationKind.highlight,
    mark: row['kind'] == 'ink' ? _markOf(row) : null,
    bookId: row['book_id'] as String,
    page: row['page'] as int,
    color:
        HighlightColor.values.asNameMap()[row['color']] ??
        HighlightColor.yellow,
    rects: [
      for (final v in jsonDecode(row['rects'] as String) as List)
        (v as num).toDouble(),
    ],
    text: row['text'] as String,
    note: row['note'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );

  Note _note(Row row) => Note(
    id: row['id'] as String,
    body: row['body'] as String,
    bookId: row['book_id'] as String?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );

  /// The drawn mark of an ink row. Strokes saved before pens had styles
  /// carry only their points and color name.
  Mark _markOf(Row row) {
    final style = row['style'] as String;
    final points = [
      for (final v in jsonDecode(row['rects'] as String) as List)
        (v as num).toDouble(),
    ];
    final styled = style.isEmpty ? null : Mark.fromJson(jsonDecode(style));
    if (styled != null) return styled.copyWith(points: points);
    const legacy = {
      'yellow': Color(0xFFD99A00),
      'green': Color(0xFF1E9E4A),
      'blue': Color(0xFF1F6FEB),
      'pink': Color(0xFFE0408A),
      'purple': Color(0xFF8A4FD8),
    };
    return Mark(
      tool: MarkTool.pen,
      color: legacy[row['color']] ?? const Color(0xFF1F6FEB),
      width: 1.4,
      points: points,
    );
  }

  Book _book(Row row) => Book(
    id: row['id'] as String,
    title: row['title'] as String,
    format: row['format'] as String,
    fileName: row['file_name'] as String,
    pageCount: row['page_count'] as int,
    addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int),
    openedAt: switch (row['opened_at']) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    },
    lastPage: row['last_page'] as int?,
    lastFraction: (row['last_fy'] as num?)?.toDouble() ?? 0,
  );
}

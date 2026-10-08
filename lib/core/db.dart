import 'package:sqlite3/sqlite3.dart';

/// Opens the app database and brings its schema up to date.
///
/// Every synced table carries `updated_at` (ms since epoch) and a `deleted`
/// tombstone so cloud sync can merge rows later without a schema change.
Database openAppDatabase(String path) {
  final db = sqlite3.open(path);
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA synchronous = NORMAL');
  db.execute('PRAGMA foreign_keys = ON');
  _migrate(db);
  return db;
}

Database openMemoryDatabase() {
  final db = sqlite3.openInMemory();
  _migrate(db);
  return db;
}

const _migrations = <String>[
  '''
  CREATE TABLE books (
    id TEXT NOT NULL PRIMARY KEY,
    title TEXT NOT NULL,
    format TEXT NOT NULL,
    file_name TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    size INTEGER NOT NULL,
    page_count INTEGER NOT NULL DEFAULT 0,
    added_at INTEGER NOT NULL,
    opened_at INTEGER,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );
  CREATE INDEX books_sha256 ON books (sha256);

  -- One row per book per device: each device keeps its own position so the
  -- other one can offer "continue from page N" instead of jumping.
  CREATE TABLE reading_state (
    book_id TEXT NOT NULL REFERENCES books (id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    page INTEGER NOT NULL,
    fx REAL NOT NULL,
    fy REAL NOT NULL,
    zoom_rel REAL NOT NULL,
    tint TEXT,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (book_id, device_id)
  );

  CREATE TABLE settings (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
  );
  ''',
  '''
  CREATE TABLE annotations (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id) ON DELETE CASCADE,
    page INTEGER NOT NULL,
    kind TEXT NOT NULL,
    color TEXT NOT NULL,
    -- JSON list of PDF-space rectangles: [left, top, right, bottom, ...]
    rects TEXT NOT NULL,
    text TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );
  CREATE INDEX annotations_book ON annotations (book_id, page);

  CREATE TABLE notes (
    id TEXT NOT NULL PRIMARY KEY,
    body TEXT NOT NULL,
    book_id TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );

  -- Holds search-normalized text; rows are maintained by Library.
  CREATE VIRTUAL TABLE search_index USING fts5 (
    kind UNINDEXED, ref UNINDEXED, body,
    tokenize = 'unicode61 remove_diacritics 2'
  );
  ''',
  '''
  CREATE TABLE projects (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );

  CREATE TABLE tasks (
    id TEXT NOT NULL PRIMARY KEY,
    title TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    project_id TEXT,
    parent_id TEXT,
    status TEXT NOT NULL DEFAULT 'todo',
    priority INTEGER NOT NULL DEFAULT 0,
    -- Whole days since 1970-01-01, or NULL for no due date.
    due_day INTEGER,
    repeat TEXT NOT NULL DEFAULT 'none',
    -- What the task was made from: 'annotation' or 'note', with its id.
    source_kind TEXT,
    source_id TEXT,
    done_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );
  CREATE INDEX tasks_parent ON tasks (parent_id);
  ''',
  '''
  -- Columns of a project's board, as in Trello.
  CREATE TABLE lists (
    id TEXT NOT NULL PRIMARY KEY,
    project_id TEXT NOT NULL,
    name TEXT NOT NULL,
    position REAL NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );
  ALTER TABLE tasks ADD COLUMN list_id TEXT;
  -- Order of a card inside its list; a card dropped between two others
  -- takes the midpoint of their positions.
  ALTER TABLE tasks ADD COLUMN position REAL NOT NULL DEFAULT 0;
  -- Comma-separated label color names.
  ALTER TABLE tasks ADD COLUMN labels TEXT NOT NULL DEFAULT '';
  UPDATE tasks SET position = created_at;
  ''',
  '''
  -- Devices that have synced, so a reading position can say where it
  -- came from.
  CREATE TABLE devices (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  );
  ''',
  '''
  -- How a drawn mark looks: JSON with its tool, color and width.
  ALTER TABLE annotations ADD COLUMN style TEXT NOT NULL DEFAULT '';

  CREATE TABLE notebooks (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    -- Set when the notebook collects pages attached to one book.
    book_id TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );

  CREATE TABLE pages (
    id TEXT NOT NULL PRIMARY KEY,
    notebook_id TEXT NOT NULL,
    position REAL NOT NULL,
    paper TEXT NOT NULL DEFAULT 'blank',
    -- JSON list of the marks drawn and typed on the page.
    content TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );
  CREATE INDEX pages_notebook ON pages (notebook_id, position);
  ''',
];

void _migrate(Database db) {
  var version = db.select('PRAGMA user_version').first.columnAt(0) as int;
  while (version < _migrations.length) {
    db.execute('BEGIN');
    try {
      db.execute(_migrations[version]);
      version++;
      db.execute('PRAGMA user_version = $version');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:varagh/core/db.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/data/models.dart';
import 'package:varagh/sync/sync_engine.dart';
import 'package:varagh/sync/sync_store.dart';

void main() {
  late Directory root;
  late Library laptop, phone;
  late SyncStore store;
  var time = 1000;

  Library device(String name) => Library(
    openMemoryDatabase(),
    (Directory(p.join(root.path, name))..createSync()).path,
    clock: () => time++,
  );

  Future<SyncReport> sync(Library library) => SyncEngine(library, store).run();

  /// Both devices exchange until neither has anything new.
  Future<void> syncBoth() async {
    await sync(laptop);
    await sync(phone);
    await sync(laptop);
  }

  Book addBook(Library library) {
    final sha = 'f' * 64;
    final id = sha.substring(0, 32);
    final book = library.addBook(
      id: id,
      title: 'Fluent Python',
      format: 'pdf',
      fileName: '$id.pdf',
      sha256: sha,
      size: 3,
      pageCount: 1011,
    );
    Directory(library.booksDir).createSync(recursive: true);
    library.fileOf(book).writeAsStringSync('pdf');
    return book;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('varagh_sync');
    store = FolderSyncStore(p.join(root.path, 'cloud'));
    laptop = device('laptop');
    phone = device('phone');
  });

  tearDown(() {
    laptop.db.close();
    phone.db.close();
    root.deleteSync(recursive: true);
  });

  test('notes, tasks and boards made on one device reach the other', () async {
    final note = laptop.addNote(body: 'Plan\nread chapter 7');
    final project = laptop.addProject('Thesis', listNames: ['A', 'B']);
    final task = laptop.addTask(title: 'Write intro', projectId: project.id);
    laptop.setTaskLabels(task.id, {TaskLabel.red});

    await syncBoth();

    expect(phone.note(note.id)!.body, 'Plan\nread chapter 7');
    expect(phone.projects().single.name, 'Thesis');
    expect(phone.lists(project.id).map((l) => l.name), ['A', 'B']);
    final arrived = phone.task(task.id)!;
    expect(arrived.labels, {TaskLabel.red});
    expect(arrived.listId, laptop.task(task.id)!.listId);
    expect(phone.search('intro').single.task!.id, task.id);
  });

  test('the later edit of the same note wins on both devices', () async {
    final note = laptop.addNote(body: 'first');
    await syncBoth();
    laptop.updateNote(note.id, 'edited on laptop');
    phone.updateNote(note.id, 'edited on phone, later');

    await syncBoth();

    expect(laptop.note(note.id)!.body, 'edited on phone, later');
    expect(phone.note(note.id)!.body, 'edited on phone, later');
  });

  test('a deletion travels and is not undone by the other copy', () async {
    final note = laptop.addNote(body: 'temp');
    await syncBoth();
    phone.removeNote(note.id);

    await syncBoth();

    expect(laptop.note(note.id), isNull);
    expect(laptop.search('temp'), isEmpty);
  });

  test(
    'a book, its file, highlights and position follow to the phone',
    () async {
      final book = addBook(laptop);
      laptop.addHighlight(
        bookId: book.id,
        page: 243,
        color: HighlightColor.yellow,
        rects: [1, 2, 3, 4],
        text: 'call by sharing',
      );
      laptop.saveReadingState(book.id, const ReadingState(page: 243, fy: 0.4));
      final arrivals = <String>[];

      await sync(laptop);
      final report = await SyncEngine(
        phone,
        store,
        onBookArrived: (b) async => arrivals.add(b.id),
      ).run();

      expect(report.booksDownloaded, 1);
      expect(arrivals, [book.id]);
      final onPhone = phone.book(book.id)!;
      expect(phone.fileOf(onPhone).readAsStringSync(), 'pdf');
      expect(phone.annotations(book.id).single.text, 'call by sharing');
      // The phone has not opened it yet, so it has no position of its own.
      expect(onPhone.lastPage, isNull);
      final elsewhere = phone.newerPositionElsewhere(book.id)!;
      expect(elsewhere.state.page, 243);
      expect(elsewhere.state.fy, 0.4);
      expect(elsewhere.device, laptop.deviceName);
    },
  );

  test(
    'the offer to continue only appears for a newer, different page',
    () async {
      final book = addBook(laptop);
      laptop.saveReadingState(book.id, const ReadingState(page: 10));
      await syncBoth();

      phone.saveReadingState(book.id, const ReadingState(page: 10));
      expect(phone.newerPositionElsewhere(book.id), isNull);
      phone.saveReadingState(book.id, const ReadingState(page: 50));
      expect(phone.newerPositionElsewhere(book.id), isNull);

      await syncBoth();
      expect(laptop.newerPositionElsewhere(book.id)!.state.page, 50);
      laptop.saveReadingState(book.id, const ReadingState(page: 60));
      expect(laptop.newerPositionElsewhere(book.id), isNull);
    },
  );

  test('the same file added on both devices becomes one book', () async {
    addBook(laptop);
    addBook(phone);
    await syncBoth();
    expect(laptop.books(), hasLength(1));
    expect(phone.books(), hasLength(1));
  });

  test('removing a book on one device removes its file on the other', () async {
    final book = addBook(laptop);
    await syncBoth();
    final onPhone = phone.book(book.id)!;
    expect(phone.fileOf(onPhone).existsSync(), isTrue);

    laptop.removeBook(book);
    await syncBoth();

    expect(phone.books(), isEmpty);
    expect(phone.fileOf(onPhone).existsSync(), isFalse);
  });

  test('a sync with nothing new writes nothing', () async {
    laptop.addNote(body: 'x');
    await syncBoth();
    await sync(phone);
    final quiet = await sync(laptop);
    expect(quiet.rowsMerged, 0);
    expect(quiet.uploadedState, isFalse);
    expect(quiet.booksUploaded, 0);
  });

  test('book files stay local when file sync is off', () async {
    addBook(laptop);
    await SyncEngine(laptop, store, syncBookFiles: false).run();
    expect(await store.list('books'), isEmpty);
    expect(await store.list('state'), hasLength(1));
  });

  test(
    'a half-written state file is skipped, then read once complete',
    () async {
      laptop.addNote(body: 'x');
      await sync(laptop);
      final name = (await store.list('state')).single.name;
      final good = await store.read('state/$name');
      await store.write('state/$name', good.sublist(0, good.length ~/ 2));

      expect((await sync(phone)).rowsMerged, 0);
      await store.write('state/$name', good);
      expect((await sync(phone)).rowsMerged, greaterThan(0));
      expect(phone.notes(), hasLength(1));
    },
  );
}

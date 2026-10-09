import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:varagh/core/db.dart';
import 'package:varagh/data/backup.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/data/models.dart';

void main() {
  late Directory root;
  late Library laptop, phone;
  late File backup;
  var time = 1000;

  Library device(String name) => Library(
    openMemoryDatabase(),
    (Directory(p.join(root.path, name))..createSync()).path,
    clock: () => time++,
  );

  Book addBook(Library library, String letter, String title) {
    final sha = letter * 64;
    final id = sha.substring(0, 32);
    final book = library.addBook(
      id: id,
      title: title,
      format: 'pdf',
      fileName: '$id.pdf',
      sha256: sha,
      size: 3,
      pageCount: 300,
    );
    Directory(library.booksDir).createSync(recursive: true);
    library.fileOf(book).writeAsStringSync('pdf of $title');
    return book;
  }

  Annotation highlight(Library library, Book book, String text) =>
      library.addHighlight(
        bookId: book.id,
        page: 4,
        color: HighlightColor.green,
        rects: [1, 2, 3, 4],
        text: text,
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('varagh_backup');
    backup = File(p.join(root.path, 'out.varagh'));
    laptop = device('laptop');
    phone = device('phone');
  });

  tearDown(() {
    laptop.db.close();
    phone.db.close();
    root.deleteSync(recursive: true);
  });

  test('one book travels with its file and everything on it', () async {
    final book = addBook(laptop, 'a', 'Fluent Python');
    final other = addBook(laptop, 'b', 'Dune');
    highlight(laptop, book, 'descriptors');
    highlight(laptop, other, 'spice');
    laptop.addNote(body: 'about the book', bookId: book.id);
    laptop.addNote(body: 'shopping list');
    laptop.addTask(title: 'unrelated');
    final sheet = laptop.addPage(laptop.notebookFor(book).id);
    laptop.saveReadingState(book.id, const ReadingState(page: 42));

    await exportBackup(laptop, backup, book: book);
    final report = await importBackup(phone, backup);

    expect(report.booksAdded.single.id, book.id);
    expect(phone.books().single.title, 'Fluent Python');
    expect(phone.fileOf(book).readAsStringSync(), 'pdf of Fluent Python');
    expect(phone.annotations(book.id).single.text, 'descriptors');
    expect(phone.notes().single.body, 'about the book');
    expect(phone.page(sheet.id), isNotNull);
    expect(phone.tasks(), isEmpty);
    expect(phone.newerPositionElsewhere(book.id)!.state.page, 42);
    expect(phone.search('descriptors').single.annotation, isNotNull);
  });

  test('the whole library travels in one file', () async {
    final book = addBook(laptop, 'a', 'Fluent Python');
    addBook(laptop, 'b', 'Dune');
    highlight(laptop, book, 'descriptors');
    laptop.addNote(body: 'shopping list');
    final project = laptop.addProject('Thesis', listNames: ['A']);
    laptop.addTask(title: 'Write intro', projectId: project.id);

    await exportBackup(laptop, backup);
    final report = await importBackup(phone, backup);

    expect(report.booksAdded, hasLength(2));
    expect(phone.books().map((b) => b.title), {'Fluent Python', 'Dune'});
    expect(phone.notes().single.body, 'shopping list');
    expect(phone.tasks().single.title, 'Write intro');
  });

  test('importing keeps what is here and the newer edit of the rest', () async {
    final book = addBook(laptop, 'a', 'Fluent Python');
    final note = laptop.addNote(body: 'first', bookId: book.id);
    await exportBackup(laptop, backup, book: book);
    await importBackup(phone, backup);

    phone.updateNote(note.id, 'edited on the phone');
    final own = phone.addNote(body: 'only here');
    final report = await importBackup(phone, backup);

    expect(report.booksAdded, isEmpty);
    expect(phone.note(note.id)!.body, 'edited on the phone');
    expect(phone.note(own.id), isNotNull);
  });

  test('a book removed here comes back when it is imported', () async {
    final book = addBook(laptop, 'a', 'Fluent Python');
    highlight(laptop, book, 'descriptors');
    await exportBackup(laptop, backup, book: book);
    await importBackup(phone, backup);
    phone.removeBook(phone.book(book.id)!);
    expect(phone.books(), isEmpty);

    final report = await importBackup(phone, backup);

    expect(report.booksAdded.single.id, book.id);
    expect(phone.fileOf(book).existsSync(), isTrue);
    expect(phone.annotations(book.id).single.text, 'descriptors');
  });

  test('a file that is not a backup is refused', () async {
    backup.writeAsStringSync('just some text');
    await expectLater(importBackup(phone, backup), throwsFormatException);
    expect(phone.books(), isEmpty);
  });

  test('file names are safe on every file system', () {
    expect(safeFileName('a/b: c?'), 'a b c');
    expect(safeFileName('///'), 'book');
    final book = addBook(laptop, 'a', 'What is "x"?');
    expect(
      backupFileName(book: book, now: DateTime(2026, 3, 5)),
      'What is x.varagh',
    );
    expect(
      backupFileName(now: DateTime(2026, 3, 5)),
      'varagh-2026-03-05.varagh',
    );
  });
}

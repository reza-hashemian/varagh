import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/core/calendar.dart';
import 'package:varagh/core/db.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/data/models.dart';
import 'package:varagh/draw/mark.dart';
import 'package:varagh/reader/page_tint.dart';

void main() {
  late Directory dir;
  late Library library;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('varagh_test');
    library = Library(openMemoryDatabase(), dir.path);
  });

  tearDown(() {
    library.db.close();
    dir.deleteSync(recursive: true);
  });

  Book add(String id, {String sha = 'abc'}) => library.addBook(
    id: id,
    title: 'Book $id',
    format: 'pdf',
    fileName: '$id.pdf',
    sha256: sha,
    size: 10,
    pageCount: 200,
  );

  test('device id is created once and kept', () {
    final again = Library(library.db, dir.path);
    expect(again.deviceId, library.deviceId);
    expect(library.deviceId, hasLength(32));
  });

  test('a new book has no position and no progress', () {
    final book = add('a');
    expect(book.lastPage, isNull);
    expect(book.progress, isNull);
    expect(library.readingState('a'), isNull);
  });

  test('reading position survives a save and reload', () {
    add('a');
    library.saveReadingState(
      'a',
      const ReadingState(
        page: 142,
        fx: 0.5,
        fy: 0.25,
        zoomRel: 1.5,
        tint: PageTint(paper: PagePaper.sepia, strength: 0.8),
      ),
    );
    library.saveReadingState(
      'a',
      library.readingState('a')!.copyWith(page: 143),
    );

    final state = library.readingState('a')!;
    expect(state.page, 143);
    expect(state.fy, 0.25);
    expect(state.zoomRel, 1.5);
    expect(state.tint, const PageTint(paper: PagePaper.sepia, strength: 0.8));
    expect(library.book('a')!.lastPage, 143);
    expect(library.book('a')!.progress, closeTo(143 / 200, 1e-9));
  });

  test('the most recently opened book is listed first', () {
    add('a', sha: '1');
    add('b', sha: '2');
    library.db.execute("UPDATE books SET opened_at = 5 WHERE id = 'a'");
    library.markOpened('b', pageCount: 321);
    expect(library.books().first.id, 'b');
    expect(library.book('b')!.pageCount, 321);
  });

  test('removing a book hides it, deletes its file and frees its hash', () {
    final book = add('a', sha: 'same');
    Directory(library.booksDir).createSync(recursive: true);
    library.fileOf(book).writeAsStringSync('x');
    library.saveReadingState('a', const ReadingState(page: 3));

    library.removeBook(book);

    expect(library.books(), isEmpty);
    expect(library.fileOf(book).existsSync(), isFalse);
    expect(library.bookBySha256('same'), isNull);
    expect(library.readingState('a'), isNull);
  });

  test('highlights are stored per page and can be recolored and noted', () {
    add('a');
    final h = library.addHighlight(
      bookId: 'a',
      page: 7,
      color: HighlightColor.yellow,
      rects: [10, 700, 200, 688],
      text: 'reading leaves a trace',
    );
    library.addHighlight(
      bookId: 'a',
      page: 2,
      color: HighlightColor.blue,
      rects: [1, 2, 3, 4],
      text: 'earlier page',
    );
    library.updateAnnotation(h.id, color: HighlightColor.pink);
    library.updateAnnotation(h.id, note: 'compare with chapter 3');

    final all = library.annotations('a');
    expect(all.map((a) => a.page), [2, 7]);
    final saved = library.annotation(h.id)!;
    expect(saved.color, HighlightColor.pink);
    expect(saved.note, 'compare with chapter 3');
    expect(saved.rects, [10, 700, 200, 688]);

    library.removeAnnotation(h.id);
    expect(library.annotations('a'), hasLength(1));
  });

  test('note title and preview come from its lines', () {
    final note = library.addNote(body: '# Plan\n\n**first**\n- second');
    expect(note.title, 'Plan');
    expect(note.preview, 'first second');
    library.updateNote(note.id, 'Changed');
    expect(library.note(note.id)!.title, 'Changed');
    library.removeNote(note.id);
    expect(library.notes(), isEmpty);
  });

  test('search finds titles, highlights, highlight notes and notes', () {
    add('a');
    final h = library.addHighlight(
      bookId: 'a',
      page: 1,
      color: HighlightColor.yellow,
      rects: [0, 1, 2, 3],
      text: 'the mitochondria is the powerhouse',
    );
    library.updateAnnotation(h.id, note: 'biology exam');
    final note = library.addNote(body: 'Groceries\nmilk and bread');

    expect(library.search('book').single.kind, SearchKind.book);
    expect(library.search('mitoch').single.annotation!.id, h.id);
    expect(library.search('exam').single.annotation!.id, h.id);
    expect(library.search('bread milk').single.note!.id, note.id);
    expect(library.search('nothinghere'), isEmpty);
    expect(library.search('  '), isEmpty);
    expect(library.search('"quoted'), isEmpty);

    library.removeNote(note.id);
    expect(library.search('milk'), isEmpty);
    library.removeBook(library.book('a')!);
    expect(library.search('mitoch'), isEmpty);
    expect(library.search('book'), isEmpty);
  });

  test('Persian search ignores yeh, kaf and half-space variants', () {
    final note = library.addNote(body: 'کتاب‌های علمی');
    // Typed with Arabic kaf and yeh, and without the half-space.
    expect(library.search('\u0643تابها').single.note!.id, note.id);
    expect(library.search('علم\u064A').single.note!.id, note.id);
  });

  test('books added before search existed get indexed on open', () {
    add('a');
    library.db.execute('DELETE FROM search_index');
    final reopened = Library(library.db, dir.path);
    expect(reopened.search('book'), hasLength(1));
  });

  test('tasks sort open-first by due date and carry subtask counts', () {
    final late = library.addTask(title: 'later', dueDay: 110);
    final soon = library.addTask(title: 'soon', dueDay: 101);
    final someday = library.addTask(title: 'someday');
    library.addTask(title: 'step 1', parentId: soon.id);
    final step2 = library.addTask(title: 'step 2', parentId: soon.id);
    library.setTaskStatus(step2.id, TaskStatus.done, today: 100);
    library.setTaskStatus(late.id, TaskStatus.done, today: 100);

    final all = library.tasks();
    expect(all.map((t) => t.title), ['soon', 'someday', 'later']);
    expect(all.first.subtaskCount, 2);
    expect(all.first.subtasksDone, 1);
    expect(library.subtasks(soon.id), hasLength(2));
    expect(library.dueTaskCount(100), 0);
    expect(library.dueTaskCount(101), 1);

    library.removeTask(soon.id);
    expect(library.subtasks(soon.id), isEmpty);
    expect(library.tasks().map((t) => t.id), [someday.id, late.id]);
  });

  test('task fields update, clear and are searchable', () {
    final project = library.addProject('Thesis');
    final task = library.addTask(title: 'Write intro', projectId: project.id);
    library.updateTask(task.id, notes: 'cite Ramalho', priority: 3);
    library.setTaskDue(task.id, 200);
    expect(library.task(task.id)!.priority, 3);
    expect(library.task(task.id)!.dueDay, 200);
    expect(library.search('ramalho').single.task!.id, task.id);

    library.setTaskDue(task.id, null);
    expect(library.task(task.id)!.dueDay, isNull);
    library.removeProject(project.id);
    expect(library.projects(), isEmpty);
    expect(library.task(task.id)!.projectId, isNull);
  });

  test('finishing a repeating task moves it to its next date', () {
    final task = library.addTask(title: 'review', dueDay: 100);
    library.updateTask(task.id, repeat: TaskRepeat.weekly);
    final step = library.addTask(title: 'step', parentId: task.id);
    library.setTaskStatus(step.id, TaskStatus.done, today: 100);

    // Finished nine days late: skips the missed week.
    library.setTaskStatus(task.id, TaskStatus.done, today: 109);

    final next = library.task(task.id)!;
    expect(next.status, TaskStatus.todo);
    expect(next.dueDay, 114);
    expect(next.subtasksDone, 0);
  });

  test('monthly repeats keep the day of month and clamp short months', () {
    final jan31 = dayOf(DateTime(2026, 1, 31));
    final feb = nextDueDay(jan31, TaskRepeat.monthly, today: jan31);
    expect(dateOfDay(feb), DateTime(2026, 2, 28));
    final oct5 = dayOf(DateTime(2026, 10, 5));
    expect(
      dateOfDay(nextDueDay(oct5, TaskRepeat.monthly, today: oct5)),
      DateTime(2026, 11, 5),
    );
    expect(nextDueDay(50, TaskRepeat.daily, today: 60), 61);
  });

  test('a new project board has its columns and cards join the first', () {
    final project = library.addProject('Thesis', listNames: ['A', 'B', 'C']);
    final lists = library.lists(project.id);
    expect(lists.map((l) => l.name), ['A', 'B', 'C']);
    final one = library.addTask(title: 'one', projectId: project.id);
    final two = library.addTask(title: 'two', projectId: project.id);
    expect(library.board(project.id)[lists.first.id]!.map((t) => t.id), [
      one.id,
      two.id,
    ]);
  });

  test('cards move between columns and keep the dropped order', () {
    final project = library.addProject('P', listNames: ['A', 'B']);
    final [a, b] = library.lists(project.id);
    final ids = [
      for (final title in ['1', '2', '3'])
        library.addTask(title: title, projectId: project.id).id,
    ];
    List<String> titles(TaskList list) => [
      for (final t in library.board(project.id)[list.id] ?? <Task>[]) t.title,
    ];

    library.moveTask(ids[2], listId: a.id, beforeTaskId: ids[0]);
    expect(titles(a), ['3', '1', '2']);
    library.moveTask(ids[0], listId: a.id, beforeTaskId: ids[2]);
    expect(titles(a), ['1', '3', '2']);
    library.moveTask(ids[2], listId: b.id);
    library.moveTask(ids[1], listId: b.id, beforeTaskId: ids[2]);
    expect(titles(a), ['1']);
    expect(titles(b), ['2', '3']);
    library.moveTask(ids[0], listId: b.id, beforeTaskId: ids[2]);
    expect(titles(b), ['2', '1', '3']);
  });

  test('removing a column moves its cards to the first one left', () {
    final project = library.addProject('P', listNames: ['A', 'B']);
    final [a, b] = library.lists(project.id);
    final task = library.addTask(title: 'x', projectId: project.id);
    library.moveTask(task.id, listId: b.id);
    library.removeList(b.id);
    expect(library.lists(project.id).single.id, a.id);
    expect(library.task(task.id)!.listId, a.id);
    library.renameList(a.id, 'Renamed');
    expect(library.lists(project.id).single.name, 'Renamed');
  });

  test('an older project gets columns from its task statuses', () {
    final project = library.addProject('Old');
    final todo = library.addTask(title: 'todo', projectId: project.id);
    final doing = library.addTask(title: 'doing', projectId: project.id);
    final done = library.addTask(title: 'done', projectId: project.id);
    library.db.execute("UPDATE tasks SET status = 'doing' WHERE id = ?", [
      doing.id,
    ]);
    library.setTaskStatus(done.id, TaskStatus.done, today: 1);

    library.ensureLists(project.id, ['To do', 'Doing', 'Done']);
    library.ensureLists(project.id, ['x', 'y', 'z']);

    final lists = library.lists(project.id);
    expect(lists.map((l) => l.name), ['To do', 'Doing', 'Done']);
    expect(library.task(todo.id)!.listId, lists[0].id);
    expect(library.task(doing.id)!.listId, lists[1].id);
    expect(library.task(doing.id)!.status, TaskStatus.todo);
    expect(library.task(done.id)!.listId, lists[2].id);
  });

  test('labels and project changes are stored on the card', () {
    final project = library.addProject('P', listNames: ['A']);
    final task = library.addTask(title: 'x');
    expect(task.listId, isNull);
    library.setTaskLabels(task.id, {TaskLabel.red, TaskLabel.blue});
    library.setTaskProject(task.id, project.id);
    final moved = library.task(task.id)!;
    expect(moved.labels, {TaskLabel.red, TaskLabel.blue});
    expect(moved.listId, library.lists(project.id).single.id);
    library.setTaskProject(task.id, null);
    expect(library.task(task.id)!.listId, isNull);
  });

  test('drawings keep their tool, color and width', () {
    add('a');
    const mark = Mark(
      tool: MarkTool.marker,
      color: Color(0xFFF2C200),
      width: 4.5,
      points: [10, 20, 30, 40, 50, 60],
    );
    final stroke = library.addInk(bookId: 'a', page: 3, mark: mark);
    final saved = library.annotations('a').single;
    expect(saved.id, stroke.id);
    expect(saved.kind, AnnotationKind.ink);
    expect(saved.mark!.tool, MarkTool.marker);
    expect(saved.mark!.color, const Color(0xFFF2C200));
    expect(saved.mark!.width, 4.5);
    expect(saved.mark!.points, [10, 20, 30, 40, 50, 60]);
  });

  test('a stroke saved before pens had styles still draws as a pen', () {
    add('a');
    library.db.execute(
      'INSERT INTO annotations (id, book_id, page, kind, color, rects, text, '
      "created_at, updated_at) VALUES ('old', 'a', 1, 'ink', 'green', "
      "'[1,2,3,4]', '', 1, 1)",
    );
    final mark = library.annotation('old')!.mark!;
    expect(mark.tool, MarkTool.pen);
    expect(mark.points, [1, 2, 3, 4]);
  });

  test('sticky notes hold text, move, and can be removed and restored', () {
    add('a');
    final sticky = library.addSticky(
      bookId: 'a',
      page: 5,
      x: 100,
      y: 700,
      color: HighlightColor.yellow,
    );
    library.updateAnnotation(sticky.id, note: 'remember this');
    library.moveAnnotation(sticky.id, 120, 650);
    final saved = library.annotation(sticky.id)!;
    expect(saved.kind, AnnotationKind.sticky);
    expect(saved.note, 'remember this');
    expect(saved.rects, [120, 650]);
    expect(library.search('remember').single.annotation!.id, sticky.id);

    library.removeAnnotation(sticky.id);
    expect(library.annotation(sticky.id), isNull);
    library.restoreAnnotation(sticky.id);
    expect(library.annotation(sticky.id)!.note, 'remember this');
    expect(library.search('remember'), hasLength(1));
  });

  test('notebook pages keep their order, paper and drawings', () {
    final notebook = library.addNotebook('Physics');
    final first = library.addPage(notebook.id);
    final second = library.addPage(notebook.id, paper: PaperStyle.grid);
    library.savePage(
      first.id,
      marks: const [
        Mark(
          tool: MarkTool.text,
          color: Color(0xFF1D1D1F),
          width: 2.4,
          points: [40, 60],
          text: 'F = ma',
        ),
      ],
    );
    library.savePage(first.id, paper: PaperStyle.lined);

    final pages = library.pages(notebook.id);
    expect(pages.map((p) => p.id), [first.id, second.id]);
    expect(pages[0].paper, PaperStyle.lined);
    expect(pages[0].marks.single.text, 'F = ma');
    expect(pages[1].paper, PaperStyle.grid);
    expect(library.notebooks().single.pageCount, 2);

    library.removePage(first.id);
    expect(library.pages(notebook.id).single.id, second.id);
    library.removeNotebook(notebook.id);
    expect(library.notebooks(), isEmpty);
    expect(library.page(second.id), isNull);
  });

  test('a page attached to a book lives in the notebook of that book', () {
    final book = add('a');
    final notebook = library.notebookFor(book);
    expect(library.notebookFor(book).id, notebook.id);
    expect(notebook.name, book.title);
    final page = library.addPage(notebook.id);
    final link = library.addPageLink(
      bookId: 'a',
      page: 9,
      x: 50,
      y: 60,
      pageId: page.id,
    );
    final saved = library.annotation(link.id)!;
    expect(saved.kind, AnnotationKind.page);
    expect(saved.text, page.id);
  });

  test('progress of a reflowable book counts the spot inside a section', () {
    library.addBook(
      id: 'e',
      title: 'Novel',
      format: 'epub',
      fileName: 'e.epub',
      sha256: 'e1',
      size: 1,
      pageCount: 4,
    );
    library.saveReadingState('e', const ReadingState(page: 2, fy: 0.5));
    final book = library.book('e')!;
    expect(book.isPdf, isFalse);
    expect(book.progress, closeTo(1.5 / 4, 1e-9));
  });

  test('settings can be set, replaced and cleared', () {
    library.setSetting('k', '1');
    library.setSetting('k', '2');
    expect(library.setting('k'), '2');
    library.setSetting('k', null);
    expect(library.setting('k'), isNull);
  });
}

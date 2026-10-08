import '../draw/mark.dart';
import '../reader/page_tint.dart';

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.format,
    required this.fileName,
    required this.pageCount,
    required this.addedAt,
    this.openedAt,
    this.lastPage,
    this.lastFraction = 0,
  });

  final String id;
  final String title;
  final String format;
  final String fileName;
  final int pageCount;
  final DateTime addedAt;
  final DateTime? openedAt;

  /// Page (or, for reflowable books, section) this device last showed;
  /// null if the book was never opened here.
  final int? lastPage;

  /// How far down that section the reader was, 0..1. Only reflowable
  /// books use it.
  final double lastFraction;

  bool get isPdf => format == 'pdf';

  /// 0..1, or null when it can't be known yet.
  double? get progress {
    final page = lastPage;
    if (page == null || pageCount <= 0) return null;
    // A PDF page is small enough to count whole; a section of a reflowable
    // book can be a whole chapter, so the spot inside it counts too.
    final done = isPdf ? page.toDouble() : page - 1 + lastFraction;
    return (done / pageCount).clamp(0.0, 1.0);
  }
}

/// Where the reader was inside a book.
///
/// The spot is stored relative to the page and the zoom relative to the
/// viewer's cover scale, so it restores sensibly at another window size or
/// on another device.
class ReadingState {
  const ReadingState({
    required this.page,
    this.fx = 0.5,
    this.fy = 0,
    this.zoomRel = 1,
    this.tint = const PageTint(),
  });

  final int page;

  /// Center of the viewport as a fraction of the page width and height.
  final double fx, fy;

  final double zoomRel;
  final PageTint tint;

  ReadingState copyWith({
    int? page,
    double? fx,
    double? fy,
    double? zoomRel,
    PageTint? tint,
  }) => ReadingState(
    page: page ?? this.page,
    fx: fx ?? this.fx,
    fy: fy ?? this.fy,
    zoomRel: zoomRel ?? this.zoomRel,
    tint: tint ?? this.tint,
  );
}

enum HighlightColor { yellow, green, blue, pink, purple }

enum AnnotationKind {
  /// Highlighted text.
  highlight,

  /// Something drawn: a pen stroke, a shape or typed text.
  ink,

  /// A sticky note stuck on the page, showing its text.
  sticky,

  /// A notebook page attached to a spot on the page.
  page,
}

/// Something added to a book's page, optionally with a note attached.
class Annotation {
  const Annotation({
    required this.id,
    this.kind = AnnotationKind.highlight,
    this.mark,
    required this.bookId,
    required this.page,
    required this.color,
    required this.rects,
    required this.text,
    this.note = '',
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final int page;
  final HighlightColor color;

  final AnnotationKind kind;

  /// What was drawn, for [AnnotationKind.ink].
  final Mark? mark;

  bool get isInk => kind == AnnotationKind.ink;

  /// For a highlight, a flat list of PDF-space rectangles: left, top,
  /// right, bottom, ... For the other kinds, the x, y where it sits.
  final List<double> rects;

  /// The highlighted text; for an attached page, that page's id.
  final String text;

  /// The note on a highlight or drawing; for a sticky note, what it says.
  final String note;
  final DateTime createdAt;
}

class Note {
  const Note({
    required this.id,
    required this.body,
    this.bookId,
    required this.updatedAt,
  });

  final String id;
  final String body;
  final String? bookId;
  final DateTime updatedAt;

  /// First non-empty line, without Markdown heading marks.
  String get title {
    for (final line in body.split('\n')) {
      final text = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// Text after the title line, flattened and stripped of Markdown marks for
  /// a one-line preview.
  String get preview {
    final lines = body
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^\s*([#>]+|[-*+]|\d+\.)\s+'), ''))
        .map((l) => l.replaceAll(RegExp(r'[*_`]'), '').trim())
        .where((l) => l.isNotEmpty)
        .skip(1);
    return lines.join(' ');
  }
}

enum SearchKind { book, annotation, note, task }

class SearchHit {
  const SearchHit({this.book, this.annotation, this.note, this.task});

  final Book? book;
  final Annotation? annotation;
  final Note? note;
  final Task? task;

  SearchKind get kind => task != null
      ? SearchKind.task
      : annotation != null
      ? SearchKind.annotation
      : note != null
      ? SearchKind.note
      : SearchKind.book;
}

class Project {
  const Project({required this.id, required this.name});

  final String id;
  final String name;
}

/// Column of a project's board.
class TaskList {
  const TaskList({required this.id, required this.name});

  final String id;
  final String name;
}

/// Label colors a card can carry, as in Trello.
enum TaskLabel { green, yellow, orange, red, purple, blue }

/// [doing] is only read from data made before boards had their own lists.
enum TaskStatus { todo, doing, done }

enum TaskRepeat { none, daily, weekly, monthly }

class Task {
  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.projectId,
    this.listId,
    this.parentId,
    this.labels = const {},
    this.status = TaskStatus.todo,
    this.priority = 0,
    this.dueDay,
    this.repeat = TaskRepeat.none,
    this.sourceKind,
    this.sourceId,
    this.subtaskCount = 0,
    this.subtasksDone = 0,
  });

  final String id;
  final String title;
  final String notes;
  final String? projectId;

  /// Board column the card sits in; null outside a project.
  final String? listId;

  final Set<TaskLabel> labels;

  /// Set on a subtask: the task it belongs to.
  final String? parentId;

  final TaskStatus status;

  /// 0 none, 1 low, 2 medium, 3 high.
  final int priority;

  /// Whole days since 1970-01-01, see `dayOf`.
  final int? dueDay;

  final TaskRepeat repeat;

  /// 'annotation' or 'note' when the task was made from one.
  final String? sourceKind;
  final String? sourceId;

  final int subtaskCount;
  final int subtasksDone;

  bool get isDone => status == TaskStatus.done;
}

class Notebook {
  const Notebook({
    required this.id,
    required this.name,
    this.bookId,
    this.pageCount = 0,
  });

  final String id;
  final String name;

  /// The book whose attached pages this notebook collects, if any.
  final String? bookId;

  final int pageCount;
}

enum PaperStyle { blank, lined, grid, dots }

/// One sheet of a notebook.
class NotebookPage {
  const NotebookPage({
    required this.id,
    required this.notebookId,
    required this.paper,
    required this.marks,
  });

  final String id;
  final String notebookId;
  final PaperStyle paper;
  final List<Mark> marks;
}

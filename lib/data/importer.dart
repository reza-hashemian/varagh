import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'library.dart';
import '../text/text_book.dart';
import 'models.dart';

class ImportResult {
  const ImportResult(this.book, {required this.alreadyExisted});

  final Book book;
  final bool alreadyExisted;
}

const _coverWidth = 360.0;

/// Copies a book into the library, checks that it opens, and saves its
/// cover: the first page of a PDF, or an EPUB's own cover image. Throws if
/// the file isn't readable or its type isn't supported.
Future<ImportResult> importBook(
  Library library, {
  required String name,
  required Stream<Uint8List> bytes,
}) async {
  final extension = p.extension(name).replaceFirst('.', '').toLowerCase();
  final format = extension == 'pdf' ? 'pdf' : textFormats[extension];
  if (format == null) throw FormatException('Unsupported file type: $name');

  await Directory(library.booksDir).create(recursive: true);
  var file = File(p.join(library.booksDir, '${newId()}.part'));

  try {
    final sink = file.openWrite();
    await sink.addStream(bytes);
    await sink.close();

    final digest = (await sha256.bind(file.openRead()).first).toString();
    final existing = library.bookBySha256(digest);
    if (existing != null) {
      await file.delete();
      return ImportResult(existing, alreadyExisted: true);
    }

    // The id comes from the content, so the same file added on two devices
    // is one book once they sync.
    final id = digest.substring(0, 32);
    final fileName = '$id.$format';
    file = await file.rename(p.join(library.booksDir, fileName));

    var title = p.basenameWithoutExtension(name);
    final int pageCount;
    if (format == 'pdf') {
      final document = await PdfDocument.openFile(file.path);
      try {
        pageCount = document.pages.length;
        if (pageCount == 0) throw const FormatException('PDF has no pages');
        await _renderCover(document.pages.first, library.coverOf(id));
      } finally {
        await document.dispose();
      }
    } else {
      final book = await loadTextBook(file, format);
      pageCount = book.sections.length;
      // An EPUB knows its real title; other files are named by the user.
      if (format == 'epub') title = book.title ?? title;
      await _saveCover(book, library.coverOf(id));
    }

    final book = library.addBook(
      id: id,
      title: title,
      format: format,
      fileName: fileName,
      sha256: digest,
      size: await file.length(),
      pageCount: pageCount,
    );
    return ImportResult(book, alreadyExisted: false);
  } catch (_) {
    if (file.existsSync()) file.deleteSync();
    rethrow;
  }
}

Future<void> _saveCover(TextBook book, File target) async {
  final bytes = book.coverBytes;
  if (bytes == null) return;
  try {
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
  } catch (_) {}
}

/// Renders the cover of a book whose file arrived by sync.
Future<void> renderCoverFor(Library library, Book book) async {
  if (!book.isPdf) {
    try {
      await _saveCover(
        await loadTextBook(library.fileOf(book), book.format),
        library.coverOf(book.id),
      );
    } catch (_) {}
    return;
  }
  try {
    final document = await PdfDocument.openFile(library.fileOf(book).path);
    try {
      if (document.pages.isNotEmpty) {
        await _renderCover(document.pages.first, library.coverOf(book.id));
      }
    } finally {
      await document.dispose();
    }
  } catch (_) {}
}

/// A missing cover only costs the tile its picture, so failures are ignored.
Future<void> _renderCover(PdfPage page, File target) async {
  try {
    final scale = _coverWidth / page.width;
    final rendered = await page.render(
      fullWidth: _coverWidth,
      fullHeight: page.height * scale,
      backgroundColor: 0xFFFFFFFF,
    );
    if (rendered == null) return;
    final ui.Image image;
    try {
      image = await rendered.createImage();
    } finally {
      rendered.dispose();
    }
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) return;
    await target.parent.create(recursive: true);
    await target.writeAsBytes(png.buffer.asUint8List(), flush: true);
  } catch (_) {}
}

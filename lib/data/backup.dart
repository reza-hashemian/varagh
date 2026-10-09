import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import 'library.dart';
import 'models.dart';

/// Extension of a backup file.
const backupExtension = 'varagh';

const _formatVersion = 1;
const _manifestName = 'manifest.json';
const _dataName = 'data.json';
const _booksDir = 'books';

/// Writes a backup file to [target]: a zip holding the library's rows and
/// its books' files. With [book], only that book and what belongs to it.
Future<void> exportBackup(Library library, File target, {Book? book}) async {
  final encoder = ZipFileEncoder()..create(target.path);
  try {
    void addJson(String name, Object json) =>
        encoder.addArchiveFile(ArchiveFile.string(name, jsonEncode(json)));
    addJson(_manifestName, {
      'app': 'varagh',
      'format': _formatVersion,
      'device': library.deviceId,
      'book': ?book?.id,
    });
    addJson(_dataName, {'tables': library.exportRows(bookId: book?.id)});
    for (final item in book == null ? library.books() : [book]) {
      final file = library.fileOf(item);
      if (!file.existsSync()) continue;
      // Books are compressed already; squeezing them again only costs time.
      await encoder.addFile(
        file,
        '$_booksDir/${item.fileName}',
        ZipFileEncoder.store,
      );
    }
  } finally {
    await encoder.close();
  }
}

class BackupReport {
  const BackupReport({required this.rowsMerged, required this.booksAdded});

  /// Rows that changed on this device.
  final int rowsMerged;

  /// Books whose files were copied in.
  final List<Book> booksAdded;
}

/// Folds the backup file [source] into the library: its rows merge with
/// the ones here, the more recently edited copy winning, and books this
/// device doesn't have the file of are copied in. Throws a
/// [FormatException] if the file isn't a backup this app can read.
Future<BackupReport> importBackup(Library library, File source) async {
  final input = InputFileStream(source.path);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } catch (_) {
      throw const FormatException('Not a backup file');
    }
    Object? readJson(String name) {
      final bytes = archive.find(name)?.readBytes();
      return bytes == null ? null : jsonDecode(utf8.decode(bytes));
    }

    final manifest = readJson(_manifestName);
    final data = readJson(_dataName);
    if (manifest is! Map ||
        manifest['app'] != 'varagh' ||
        manifest['format'] != _formatVersion ||
        data is! Map ||
        data['tables'] is! Map<String, Object?>) {
      throw const FormatException('Not a backup file');
    }
    final merged = library.importRows(data['tables'] as Map<String, Object?>);

    // Files are looked up by the names the library expects rather than
    // taken from the archive's own list, so a crafted archive can't write
    // outside the books folder.
    final added = <Book>[];
    await Directory(library.booksDir).create(recursive: true);
    for (final book in library.books()) {
      final target = library.fileOf(book);
      final entry = archive.find('$_booksDir/${book.fileName}');
      if (entry == null || !entry.isFile || target.existsSync()) continue;
      final part = File('${target.path}.part');
      final output = OutputFileStream(part.path);
      try {
        entry.writeContent(output);
      } finally {
        await output.close();
      }
      await part.rename(target.path);
      added.add(book);
    }
    return BackupReport(rowsMerged: merged, booksAdded: added);
  } finally {
    await input.close();
  }
}

/// A name for a backup file of [book], or of the whole library, that is
/// safe on every file system.
String backupFileName({Book? book, required DateTime now}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final date = '${now.year}-${two(now.month)}-${two(now.day)}';
  final name = book == null ? 'varagh-$date' : safeFileName(book.title);
  return '$name.$backupExtension';
}

/// [title] without the characters file systems refuse.
String safeFileName(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'book' : cleaned;
}

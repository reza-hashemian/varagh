import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../data/library.dart';
import '../data/models.dart';
import 'sync_store.dart';

class SyncReport {
  const SyncReport({
    this.rowsMerged = 0,
    this.uploadedState = false,
    this.booksUploaded = 0,
    this.booksDownloaded = 0,
  });

  /// Rows that changed on this device.
  final int rowsMerged;

  final bool uploadedState;
  final int booksUploaded;
  final int booksDownloaded;
}

/// Syncs a [Library] with a [SyncStore].
///
/// Each device keeps one file in the store holding all of its rows. A sync
/// folds every other device's file into the local database (the most
/// recently edited copy of a row wins), then rewrites this device's file if
/// anything in it changed. There is no server and nothing to coordinate:
/// devices converge as each one syncs.
class SyncEngine {
  SyncEngine(
    this.library,
    this.store, {
    this.syncBookFiles = true,
    this.onBookArrived,
  });

  final Library library;
  final SyncStore store;
  final bool syncBookFiles;

  /// Called after a book's file was downloaded, to render its cover.
  final Future<void> Function(Book book)? onBookArrived;

  static const _stateDir = 'state';
  static const _booksDir = 'books';
  static const _formatVersion = 1;

  String get _ownStateName => '${library.deviceId}.json.gz';

  Future<SyncReport> run() async {
    var merged = 0;
    for (final file in await store.list(_stateDir)) {
      if (file.name == _ownStateName || !file.name.endsWith('.json.gz')) {
        continue;
      }
      final seenKey = 'sync.seen.${file.name}';
      if (library.setting(seenKey) == file.tag) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(
          utf8.decode(gzip.decode(await store.read('$_stateDir/${file.name}'))),
        );
      } on FormatException {
        // A file caught mid-transfer; it is read again next time.
        continue;
      }
      if (decoded is! Map<String, Object?> ||
          decoded['format'] != _formatVersion ||
          decoded['tables'] is! Map<String, Object?>) {
        continue;
      }
      merged += library.mergeRows(decoded['tables']! as Map<String, Object?>);
      library.setSetting(seenKey, file.tag);
    }

    final state = Uint8List.fromList(
      gzip.encode(
        utf8.encode(
          jsonEncode({
            'format': _formatVersion,
            'device': library.deviceId,
            'tables': library.exportRows(),
          }),
        ),
      ),
    );
    final digest = sha1.convert(state).toString();
    final uploadState = library.setting('sync.uploaded') != digest;
    if (uploadState) {
      await store.write('$_stateDir/$_ownStateName', state);
      library.setSetting('sync.uploaded', digest);
    }

    var uploaded = 0, downloaded = 0;
    if (syncBookFiles) {
      final remote = {for (final f in await store.list(_booksDir)) f.name};
      for (final (:book, :sha256) in library.bookFiles()) {
        final name = '$sha256.${book.format}';
        final File local = library.fileOf(book);
        if (await local.exists()) {
          if (!remote.contains(name)) {
            await store.upload('$_booksDir/$name', local);
            uploaded++;
          }
        } else if (remote.contains(name)) {
          await store.download('$_booksDir/$name', local);
          await onBookArrived?.call(book);
          downloaded++;
        }
      }
    }

    return SyncReport(
      rowsMerged: merged,
      uploadedState: uploadState,
      booksUploaded: uploaded,
      booksDownloaded: downloaded,
    );
  }
}

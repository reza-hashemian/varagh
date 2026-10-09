import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_state.dart';
import '../core/file_dialogs.dart';
import '../data/backup.dart';
import '../data/importer.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';

Future<File> _scratchFile() async =>
    File(p.join((await getTemporaryDirectory()).path, '${newId()}.part'));

/// Makes a backup file of [book], or of the whole library, and asks where
/// to save it.
Future<void> exportBackupFrom(BuildContext context, {Book? book}) async {
  final state = AppScope.read(context);
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final scratch = await _scratchFile();
  if (!context.mounted) return;
  try {
    await runBusy(
      context,
      l.exporting,
      () => exportBackup(state.library, scratch, book: book),
    );
    final saved = await saveFileAs(
      backupFileName(book: book, now: DateTime.now()),
      scratch,
    );
    if (saved) messenger.showSnackBar(SnackBar(content: Text(l.exportSaved)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.exportFailed)));
  } finally {
    if (scratch.existsSync()) scratch.deleteSync();
  }
}

/// Asks for a backup file and folds it into the library.
Future<void> importBackupInto(BuildContext context) async {
  final state = AppScope.read(context);
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // Not filtered by extension: phones don't know this one and would grey
  // every file out.
  final picked = await FilePicker.pickFile();
  if (picked == null || !context.mounted) return;

  File? scratch;
  try {
    final report = await runBusy(context, l.importingBackup, () async {
      var source = picked.path == null ? null : File(picked.path!);
      if (source == null) {
        // A file that isn't on this device's disk is fetched first.
        source = scratch = await _scratchFile();
        final sink = source.openWrite();
        await sink.addStream(picked.readAsByteStream());
        await sink.close();
      }
      final report = await importBackup(state.library, source);
      for (final book in report.booksAdded) {
        await renderCoverFor(state.library, book);
      }
      return report;
    });
    state.reloadBooks();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l.importDone(
            NumberFormat('#', l.localeName).format(report.booksAdded.length),
          ),
        ),
      ),
    );
  } on FormatException {
    messenger.showSnackBar(SnackBar(content: Text(l.importNotBackup)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.importFailedBackup)));
  } finally {
    if (scratch case final file? when file.existsSync()) file.deleteSync();
  }
}

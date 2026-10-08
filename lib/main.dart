import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app_state.dart';
import 'core/db.dart';
import 'core/theme.dart';
import 'data/importer.dart';
import 'data/library.dart';
import 'home_shell.dart';
import 'l10n/app_localizations.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();

  final root = await getApplicationSupportDirectory();
  await Directory(root.path).create(recursive: true);
  final db = openAppDatabase(p.join(root.path, 'varagh.db'));
  final state = AppState(Library(db, root.path));
  await _openFromArguments(state, args);

  runApp(VaraghApp(state: state));
  state.sync.syncNow();
}

/// Lets the desktop app be launched with a book's path ("Open with"): the file
/// joins the library and opens straight away.
Future<void> _openFromArguments(AppState state, List<String> args) async {
  for (final arg in args) {
    final file = File(arg);
    if (!file.existsSync()) continue;
    try {
      final result = await importBook(
        state.library,
        name: p.basename(arg),
        bytes: file.openRead().map(Uint8List.fromList),
      );
      state.sessionBookId = result.book.id;
      state.reloadBooks();
    } catch (_) {
      // An unreadable file just leaves the app on the library.
    }
    return;
  }
}

class VaraghApp extends StatelessWidget {
  const VaraghApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        // Only the theme and language rebuild the whole app; everything
        // else reaches just the screens that show it.
        listenable: state.appearance,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          theme: buildTheme(state.look, state.accent),
          locale: state.localeCode == null ? null : Locale(state.localeCode!),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeShell(),
        ),
      ),
    );
  }
}

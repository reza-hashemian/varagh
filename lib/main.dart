import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app_state.dart';
import 'core/db.dart';
import 'core/open_with.dart';
import 'core/shortcuts.dart';
import 'core/theme.dart';
import 'core/windows.dart';
import 'data/library.dart';
import 'home_shell.dart';
import 'l10n/app_localizations.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();

  final root = await getApplicationSupportDirectory();
  await Directory(root.path).create(recursive: true);
  final db = openAppDatabase(p.join(root.path, 'varagh.db'));
  final extraWindow = args.contains(extraWindowArg);
  final state = AppState(Library(db, root.path), extraWindow: extraWindow);
  if (extraWindow) {
    final id = launchBookId(args);
    if (id != null) state.sessionBookIds = [id];
  } else {
    await _openFromLaunch(state, args);
  }

  registerAppShortcuts(state);
  runApp(VaraghApp(state: state));
  state.sync.syncNow();
  if (canOpenWindows) state.watchOtherWindows();
  if (!extraWindow) registerOpenWith(state.library);
}

/// Lets the app be launched on a book ("Open with"): the file joins the
/// library and opens straight away. Desktop passes its path as an argument.
Future<void> _openFromLaunch(AppState state, List<String> args) async {
  final sent = await initialOpenWithFile();
  for (final path in [?sent, ...args]) {
    if (!File(path).existsSync()) continue;
    try {
      final book = await importOpenWithFile(state.library, path);
      state.sessionBookIds = [book.id];
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

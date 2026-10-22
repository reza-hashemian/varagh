import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/core/app_state.dart';
import 'package:varagh/core/auto_hide_bars.dart';
import 'package:varagh/core/db.dart';
import 'package:varagh/core/shortcuts.dart';
import 'package:varagh/core/theme.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/l10n/app_localizations.dart';
import 'package:varagh/text/text_reader_screen.dart';

void main() {
  late Directory dir;
  late Library library;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('varagh_keys');
    library = Library(openMemoryDatabase(), dir.path);
  });

  tearDown(() {
    library.db.close();
    dir.deleteSync(recursive: true);
  });

  test('shortcuts are written the way each system writes them', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(shortcutLabel(AppKeys.pageDark), 'Ctrl+Shift+D');
    expect(shortcutLabel(AppKeys.focusMode), 'F11');
    expect(shortcutLabel(AppKeys.zoomIn), 'Ctrl++');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keys in a book flip its bars and focus mode', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The file is absent; the reader still lays out its bars.
    final book = library.addBook(
      id: 'a',
      title: 'A text',
      format: 'txt',
      fileName: 'a.txt',
      sha256: 'abc',
      size: 10,
      pageCount: 1,
    );
    final state = AppState(library);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(AppLook.paper, AppAccent.blue),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: TextReaderScreen(book: book),
        ),
      ),
    );
    // The book loads in the background and its spinner never settles.
    await tester.pump();
    expect(find.byType(AutoHideBars), findsNothing);

    Future<void> press(List<LogicalKeyboardKey> keys) async {
      for (final key in keys) {
        await tester.sendKeyDownEvent(key);
      }
      for (final key in keys.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      await tester.pump(const Duration(milliseconds: 300));
    }

    await press([
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.keyH,
    ]);
    expect(state.autoHideBars, isTrue);
    expect(find.byType(AutoHideBars), findsOneWidget);

    await press([LogicalKeyboardKey.f11]);
    expect(find.byIcon(CupertinoIcons.fullscreen_exit), findsOneWidget);
    await press([LogicalKeyboardKey.f11]);
    expect(find.byIcon(CupertinoIcons.fullscreen_exit), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(idleDelay);
    debugDefaultTargetPlatformOverride = null;
  });
}

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/core/app_state.dart';
import 'package:varagh/core/db.dart';
import 'package:varagh/core/theme.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/l10n/app_localizations.dart';
import 'package:varagh/reader/reader_screen.dart';

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

  /// The reader on a screen [width] wide, as Android lays it out. The
  /// book's file is absent, which leaves the toolbar as it always is.
  Future<void> open(WidgetTester tester, double width) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = Size(width, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final book = library.addBook(
      id: 'a',
      title: 'A book with a rather long title',
      format: 'pdf',
      fileName: 'a.pdf',
      sha256: 'abc',
      size: 10,
      pageCount: 200,
    );
    await tester.pumpWidget(
      AppScope(
        state: AppState(library),
        child: MaterialApp(
          theme: buildTheme(AppLook.paper, AppAccent.blue),
          locale: const Locale('fa'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ReaderScreen(book: book),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('on an upright phone the toolbar fits, the rest is in a menu', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0]) {
      await open(tester, width);
      // An overflowing row reports itself as an exception.
      expect(tester.takeException(), isNull, reason: 'at width $width');
      expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.fullscreen), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      for (final entry in ['ترجمه', 'خروجی PDF', 'حالت تمرکز']) {
        expect(find.text(entry), findsOneWidget);
      }
      await tester.tap(find.text('حالت تمرکز'));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.fullscreen_exit), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a wide window shows every button', (tester) async {
    await open(tester, 1000);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(CupertinoIcons.ellipsis), findsNothing);
    expect(find.byIcon(CupertinoIcons.fullscreen), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}

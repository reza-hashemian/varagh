import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/core/app_state.dart';
import 'package:varagh/core/db.dart';
import 'package:varagh/core/mac_widgets.dart';
import 'package:varagh/core/theme.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/data/models.dart';
import 'package:varagh/l10n/app_localizations.dart';
import 'package:varagh/reader/reader_desk.dart';

void main() {
  late Directory dir;
  late Library library;
  late AppState state;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('varagh_test');
    library = Library(openMemoryDatabase(), dir.path);
    state = AppState(library);
  });

  /// Lets routes and dialogs finish moving. Not pumpAndSettle, since a
  /// text book's loading spinner never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  tearDown(() {
    library.db.close();
    dir.deleteSync(recursive: true);
  });

  /// A book whose file is absent, which leaves the reader's toolbar as it
  /// always is.
  Book book(String id, String format) => library.addBook(
    id: id,
    title: 'Book $id',
    format: format,
    fileName: '$id.$format',
    sha256: id,
    size: 10,
    pageCount: 20,
  );

  /// A desk of [books] in a window [width] wide, pushed over a home page
  /// so closing its last book has somewhere to go back to.
  Future<void> open(WidgetTester tester, double width, List<Book> books) async {
    state.reloadBooks();
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Readers save as they close, so they go before the database does.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      AppScope(
        state: state,
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
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReaderDesk(books: books),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await settle(tester);
  }

  testWidgets('books sit side by side and close one at a time', (tester) async {
    await open(tester, 1900, [book('a', 'pdf'), book('b', 'md')]);
    expect(tester.takeException(), isNull);
    expect(find.text('Book a'), findsOneWidget);
    expect(find.text('Book b'), findsOneWidget);
    expect(state.sessionBookIds, ['a', 'b']);

    // Two books can scroll together; the button lights up in both.
    expect(find.byIcon(CupertinoIcons.link), findsNWidgets(2));
    await tester.tap(find.byIcon(CupertinoIcons.link).first);
    await settle(tester);
    expect(
      tester
          .widgetList<MacIconButton>(find.byType(MacIconButton))
          .where((b) => b.icon == CupertinoIcons.link && b.active),
      hasLength(2),
    );

    // Each reader closes itself rather than going back.
    expect(find.byIcon(CupertinoIcons.xmark), findsNWidgets(2));
    await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
    await settle(tester);
    expect(find.text('Book a'), findsNothing);
    expect(state.sessionBookIds, ['b']);
    // Alone, a book has nothing to scroll with.
    expect(find.byIcon(CupertinoIcons.link), findsNothing);

    // The last one goes back as a lone reader always has.
    await tester.tap(find.byIcon(CupertinoIcons.chevron_back));
    await settle(tester);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('another book opens beside the one asked from', (tester) async {
    book('b', 'pdf');
    await open(tester, 1500, [book('a', 'pdf')]);
    await tester.tap(find.byIcon(CupertinoIcons.square_split_2x1));
    await settle(tester);
    await tester.enterText(find.byType(EditableText), 'k b');
    await settle(tester);
    expect(find.text('Book a'), findsOneWidget, reason: 'only the reader');
    await tester.tap(find.text('Book b'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(state.sessionBookIds, ['a', 'b']);
  });

  testWidgets('a narrow window has no room for a second book', (tester) async {
    await open(tester, 500, [book('a', 'pdf')]);
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await settle(tester);
    expect(find.text('باز کردن کتاب کنارش'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/core/theme.dart';
import 'package:varagh/data/models.dart';
import 'package:varagh/l10n/app_localizations.dart';
import 'package:varagh/tasks/board.dart';

void main() {
  const lists = [
    TaskList(id: 'a', name: 'To read'),
    TaskList(id: 'b', name: 'Reading'),
    TaskList(id: 'c', name: 'Done'),
  ];

  Future<List<String>> showBoard(WidgetTester tester, Locale locale) async {
    // A phone-sized screen: only the first column fits.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moves = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(AppLook.paper, AppAccent.blue),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: TaskBoard(
            lists: lists,
            cards: {
              'a': [const Task(id: 't1', title: 'First card', listId: 'a')],
            },
            onAddCard: (_, _) {},
            onMove: (task, list, _) => moves.add('$task→$list'),
            onToggle: (_) {},
            onOpen: (_) {},
            onAddList: (_) {},
            onRenameList: (_, _) {},
            onDeleteList: (_) {},
          ),
        ),
      ),
    );
    return moves;
  }

  ScrollPosition boardScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Scrollable &&
                  axisDirectionToAxis(w.axisDirection) == Axis.horizontal,
            )
            .first,
      )
      .position;

  Future<void> holdAt(WidgetTester tester, TestGesture drag, Offset at) async {
    await drag.moveTo(at);
    // The finger rests at the edge while the board scrolls on its own.
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('holding a card at the edge scrolls the board to other columns', (
    tester,
  ) async {
    final moves = await showBoard(tester, const Locale('en'));
    final position = boardScroll(tester);
    expect(position.pixels, 0);

    final drag = await tester.startGesture(
      tester.getCenter(find.text('First card')),
    );
    await drag.moveBy(const Offset(20, 0));
    await tester.pump();
    await holdAt(tester, drag, const Offset(352, 100));
    expect(position.pixels, position.maxScrollExtent);

    // Back to the left edge until the middle column comes into view.
    await drag.moveTo(const Offset(8, 100));
    while (tester.getCenter(find.text('Reading')).dx < 120) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Away from the edges the board stops, and the card drops there.
    final addCard = find.text('Add a card').at(1);
    await drag.moveTo(tester.getCenter(addCard));
    await tester.pump();
    final stopped = position.pixels;
    await tester.pump(const Duration(milliseconds: 300));
    expect(position.pixels, stopped);
    await drag.up();
    await tester.pump();
    expect(moves, ['t1→b']);
  });

  testWidgets('in right-to-left the board scrolls toward the left edge', (
    tester,
  ) async {
    await showBoard(tester, const Locale('fa'));
    final position = boardScroll(tester);

    final drag = await tester.startGesture(
      tester.getCenter(find.text('First card')),
    );
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await holdAt(tester, drag, const Offset(8, 100));
    expect(position.pixels, greaterThan(0));
    await drag.up();
    await tester.pump();
  });

  testWidgets('a card that is not dragged leaves the board still', (
    tester,
  ) async {
    await showBoard(tester, const Locale('en'));
    final position = boardScroll(tester);
    final touch = await tester.startGesture(const Offset(352, 600));
    await tester.pump(const Duration(milliseconds: 500));
    await touch.up();
    expect(position.pixels, 0);
  });
}

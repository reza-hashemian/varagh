import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:varagh/core/app_state.dart';
import 'package:varagh/core/auto_hide_bars.dart';
import 'package:varagh/core/db.dart';
import 'package:varagh/core/links.dart';
import 'package:varagh/core/theme.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/reader/pdf_links.dart';

/// A one-page PDF whose page box starts at 50, 60 and holds two links: one
/// that opens `clips/video.mp4` over 100..200 × 100..150, and one to a web
/// page over 100..200 × 300..350, both in the page's own coordinates.
Uint8List linkedPdf() {
  final out = BytesBuilder();
  final offsets = <int>[];
  void object(String body) {
    offsets.add(out.length);
    out.add(latin1.encode('${offsets.length} 0 obj\n$body\nendobj\n'));
  }

  out.add(latin1.encode('%PDF-1.4\n'));
  object('<< /Type /Catalog /Pages 2 0 R >>');
  object('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  object(
    '<< /Type /Page /Parent 2 0 R /MediaBox [50 60 350 460] '
    '/Contents 4 0 R /Annots [5 0 R 6 0 R] >>',
  );
  object('<< /Length 0 >>\nstream\n\nendstream');
  object(
    '<< /Type /Annot /Subtype /Link /Rect [100 100 200 150] '
    '/A << /S /Launch /F (clips/video.mp4) >> >>',
  );
  object(
    '<< /Type /Annot /Subtype /Link /Rect [100 300 200 350] '
    '/A << /S /URI /URI (https://example.com/) >> >>',
  );
  final xref = out.length;
  out.add(
    latin1.encode(
      'xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n'
      '${[for (final o in offsets) '${'$o'.padLeft(10, '0')} 00000 n \n'].join()}'
      'trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF\n',
    ),
  );
  return out.toBytes();
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('varagh_links'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('resolveBookLink', () {
    test('passes web addresses through', () {
      expect(
        resolveBookLink('https://example.com/a?b=1'),
        Uri.parse('https://example.com/a?b=1'),
      );
      expect(resolveBookLink('mailto:a@b.c')?.scheme, 'mailto');
    });

    test('finds a file beside the book, however it is written', () {
      final video = File(p.join(dir.path, 'clips', 'my video.mp4'))
        ..createSync(recursive: true);
      final want = Uri.file(video.path);
      for (final link in [
        'clips/my video.mp4',
        'clips/my%20video.mp4',
        'run:clips/my video.mp4',
        './clips/../clips/my video.mp4',
        Uri.file(video.path).toString(),
        video.path,
      ]) {
        expect(resolveBookLink(link, folder: dir.path), want, reason: link);
      }
    });

    test('gives up on files that are not there', () {
      expect(resolveBookLink('missing.mp4', folder: dir.path), isNull);
      expect(resolveBookLink('video.mp4'), isNull);
      expect(resolveBookLink('  '), isNull);
    });
  });

  test('remembers where a book was added from', () {
    final library = Library(openMemoryDatabase(), dir.path);
    addTearDown(library.db.close);
    expect(library.sourceFolderOf('a'), isNull);
    library.setSourceFolder('a', '/books');
    expect(library.sourceFolderOf('a'), '/books');
  });

  test('the dark shortcut goes back to the look it came from', () {
    final library = Library(openMemoryDatabase(), dir.path);
    addTearDown(library.db.close);
    final state = AppState(library)..look = AppLook.light;
    state.toggleDark();
    expect(state.look, AppLook.dark);
    state.look = AppLook.black;
    state.toggleDark();
    expect(state.look, AppLook.light);
    state.toggleDark();
    expect(state.look, AppLook.black);
  });

  testWidgets('bars slide away when idle and come back on a move', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AutoHideBars(
          top: SizedBox(height: 50, child: Text('top')),
          bottom: SizedBox(height: 38, child: Text('bottom')),
          body: SizedBox.expand(),
        ),
      ),
    );
    Offset slide(String text) => tester
        .widget<AnimatedSlide>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(AnimatedSlide),
          ),
        )
        .offset;

    await tester.pump(idleDelay - const Duration(seconds: 1));
    expect(slide('top'), Offset.zero);
    await tester.pump(const Duration(seconds: 2));
    expect(slide('top'), const Offset(0, -1));
    expect(slide('bottom'), const Offset(0, 1));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(200, 300));
    await mouse.moveTo(const Offset(210, 300));
    await tester.pump();
    expect(slide('top'), Offset.zero);
    await mouse.removePointer();
    await tester.pump(idleDelay);
  });

  // `flutter test` builds PDFium next to the tests. Where it doesn't, this
  // test is skipped.
  final pdfium = File(
    p.join(
      'build',
      'native_assets',
      Platform.operatingSystem,
      Platform.isWindows
          ? 'pdfium.dll'
          : Platform.isMacOS
          ? 'libpdfium.dylib'
          : 'libpdfium.so',
    ),
  );

  testWidgets('finds the file a link opens', skip: !pdfium.existsSync(), (
    tester,
  ) async {
    await tester.runAsync(() async {
      Pdfrx.pdfiumModulePath = pdfium.absolute.path;
      Pdfrx.cacheDirectoryPath = dir.path;
      final document = await PdfDocument.openData(
        linkedPdf(),
        sourceName: 'linked',
      );
      try {
        // The viewer counts from the page box's corner, at 50, 60.
        // In the system's own way of writing a path.
        expect(
          await fileLinkAt(document, 1, 100, 65),
          p.join('clips', 'video.mp4'),
        );
        expect(await fileLinkAt(document, 1, 10, 10), isNull);
        // A web link is the viewer's to open.
        expect(await fileLinkAt(document, 1, 100, 265), isNull);
      } finally {
        await document.dispose();
      }
    });
  });
}

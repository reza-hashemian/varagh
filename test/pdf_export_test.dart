import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:varagh/data/models.dart';
import 'package:varagh/draw/mark.dart';
import 'package:varagh/reader/pdf_export.dart';

/// A PDF of [pages] pages that each say "Hello".
Uint8List buildPdf({
  int pages = 1,
  String box = '0 0 300 400',
  int rotate = 0,
}) {
  final out = BytesBuilder();
  final offsets = <int>[];
  void object(String body) {
    offsets.add(out.length);
    out.add(latin1.encode('${offsets.length} 0 obj\n$body\nendobj\n'));
  }

  out.add(latin1.encode('%PDF-1.4\n'));
  const content = 'BT /F1 24 Tf 50 300 Td (Hello) Tj ET';
  final kids = [for (var i = 0; i < pages; i++) '${4 + i * 2} 0 R'].join(' ');
  object('<< /Type /Catalog /Pages 2 0 R >>');
  object('<< /Type /Pages /Kids [$kids] /Count $pages >>');
  object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  for (var i = 0; i < pages; i++) {
    object(
      '<< /Type /Page /Parent 2 0 R /MediaBox [$box] /Rotate $rotate '
      '/Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + i * 2} 0 R >>',
    );
    object('<< /Length ${content.length} >>\nstream\n$content\nendstream');
  }
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

Annotation annotation({
  required int page,
  AnnotationKind kind = AnnotationKind.ink,
  List<double> rects = const [],
  Mark? mark,
  String note = '',
}) => Annotation(
  id: '$page-$kind-${rects.length}-${mark?.tool}',
  kind: kind,
  mark: mark,
  bookId: 'book',
  page: page,
  color: HighlightColor.yellow,
  rects: rects.isEmpty ? mark?.points ?? const [] : rects,
  text: '',
  note: note,
  createdAt: DateTime(2026),
);

const red = Color(0xFFE5383B);

/// The color of an exported page at the spot where the app shows the PDF
/// point ([x], [y]).
Future<Color> Function(double x, double y) probe(PdfPage page) {
  return (x, y) async {
    final image = (await page.render(
      fullWidth: page.width * 2,
      fullHeight: page.height * 2,
      backgroundColor: 0xFFFFFFFF,
    ))!;
    final at = PdfRect(
      x,
      y,
      x,
      y,
    ).toRect(page: page, scaledPageSize: Size(page.width, page.height) * 2);
    final i = (at.top.round() * image.width + at.left.round()) * 4;
    final color = Color.fromARGB(
      255,
      image.pixels[i + 2],
      image.pixels[i + 1],
      image.pixels[i],
    );
    image.dispose();
    return color;
  };
}

bool reddish(Color c) => c.r > 0.7 && c.g < 0.45 && c.b < 0.45;
bool white(Color c) => c.r > 0.97 && c.g > 0.97 && c.b > 0.97;

void main() {
  late Directory dir;

  // `flutter test` builds PDFium next to the tests. Where it doesn't, the
  // tests that need it are skipped.
  final built = File(
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
  final noPdfium = !built.existsSync();

  setUpAll(() {
    if (!noPdfium) Pdfrx.pdfiumModulePath = built.absolute.path;
  });

  setUp(() => dir = Directory.systemTemp.createTempSync('varagh_pdf'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(Uint8List bytes) {
    final file = File(p.join(dir.path, 'in.pdf'))..writeAsBytesSync(bytes);
    return file.path;
  }

  Future<PdfDocument> open(Uint8List bytes) =>
      PdfDocument.openData(bytes, sourceName: 'exported-${bytes.hashCode}');

  testWidgets('annotations land where the app shows them', (tester) async {
    await tester.runAsync(() async {
      Pdfrx.cacheDirectoryPath = dir.path;
      final bytes = await exportAnnotatedPdf(write(buildPdf()), [
        annotation(
          page: 1,
          kind: AnnotationKind.highlight,
          rects: [40, 330, 140, 290],
        ),
        annotation(
          page: 1,
          mark: const Mark(
            tool: MarkTool.rect,
            color: red,
            width: 4,
            points: [200, 100, 260, 60],
          ),
        ),
        annotation(
          page: 1,
          mark: const Mark(
            tool: MarkTool.pen,
            color: red,
            width: 4,
            points: [30, 30, 90, 30],
          ),
        ),
        annotation(
          page: 1,
          kind: AnnotationKind.sticky,
          rects: [150, 250],
          note: 'remember',
        ),
      ]);

      final document = await open(bytes);
      final page = document.pages.single;
      final color = probe(page);
      // Highlighted paper turns yellow but stays light.
      final marked = await color(130, 320);
      expect(marked.b, lessThan(0.75));
      expect(marked.r, greaterThan(0.9));
      // The shape's outline and the pen stroke are there, and the paper
      // inside the shape and around them shows through.
      expect(reddish(await color(200, 80)), isTrue);
      expect(white(await color(230, 80)), isTrue);
      expect(reddish(await color(60, 30)), isTrue);
      expect(white(await color(60, 45)), isTrue);
      expect(white(await color(150, 252)), isTrue);
      expect(white(await color(160, 240)), isFalse);
      // The page keeps its text.
      expect((await page.loadText())!.fullText, contains('Hello'));
      await document.dispose();
    });
  }, skip: noPdfium);

  testWidgets('a turned page with a shifted box is marked the same way', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Pdfrx.cacheDirectoryPath = dir.path;
      final source = write(buildPdf(box: '20 30 320 430', rotate: 90));
      final bytes = await exportAnnotatedPdf(source, [
        annotation(
          page: 1,
          kind: AnnotationKind.highlight,
          rects: [40, 330, 140, 290],
        ),
        annotation(
          page: 1,
          mark: const Mark(
            tool: MarkTool.pen,
            color: red,
            width: 4,
            points: [30, 30, 90, 30],
          ),
        ),
      ]);

      final document = await open(bytes);
      final page = document.pages.single;
      expect(page.width, 400);
      final color = probe(page);
      expect((await color(90, 310)).b, lessThan(0.75));
      expect(white(await color(90, 340)), isTrue);
      expect(reddish(await color(60, 30)), isTrue);
      expect(white(await color(60, 45)), isTrue);
      await document.dispose();
    });
  }, skip: noPdfium);

  testWidgets('pages with nothing on them can be left out', (tester) async {
    await tester.runAsync(() async {
      Pdfrx.cacheDirectoryPath = dir.path;
      final source = write(buildPdf(pages: 3));
      final marks = [
        annotation(
          page: 2,
          kind: AnnotationKind.highlight,
          rects: [40, 330, 140, 290],
        ),
        // An attached notebook page isn't part of an export.
        annotation(page: 3, kind: AnnotationKind.page, rects: [10, 10]),
      ];

      final all = await open(await exportAnnotatedPdf(source, marks));
      expect(all.pages, hasLength(3));
      await all.dispose();

      final some = await open(
        await exportAnnotatedPdf(source, marks, annotatedPagesOnly: true),
      );
      expect(some.pages, hasLength(1));
      expect((await probe(some.pages.single)(130, 320)).b, lessThan(0.75));
      await some.dispose();
    });
  }, skip: noPdfium);

  test('annotations are sorted into the parts of an export', () {
    Mark of(MarkTool tool) =>
        Mark(tool: tool, color: red, width: 2, points: const [0, 0, 5, 5]);
    ExportPart? part(MarkTool tool) =>
        exportPartOf(annotation(page: 1, mark: of(tool)));

    expect(part(MarkTool.brush), ExportPart.handwriting);
    expect(part(MarkTool.marker), ExportPart.handwriting);
    expect(part(MarkTool.arrow), ExportPart.shapes);
    expect(part(MarkTool.text), ExportPart.text);
    expect(
      exportPartOf(annotation(page: 1, kind: AnnotationKind.sticky)),
      ExportPart.stickies,
    );
    expect(exportPartOf(annotation(page: 1, kind: AnnotationKind.page)), null);
  });
}

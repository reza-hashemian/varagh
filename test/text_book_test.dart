import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/text/text_book.dart';

Uint8List epub({bool withCover = true}) {
  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''
<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  add('OEBPS/content.opf', '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>بوف کور</dc:title>
    ${withCover ? '<meta name="cover" content="cov"/>' : ''}
  </metadata>
  <manifest>
    <item id="c2" href="text/ch%202.xhtml" media-type="application/xhtml+xml"/>
    <item id="c1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="empty" href="text/empty.xhtml" media-type="application/xhtml+xml"/>
    <item id="cov" href="images/cover.jpg" media-type="image/jpeg"/>
  </manifest>
  <spine><itemref idref="c1"/><itemref idref="empty"/><itemref idref="c2"/></spine>
</package>''');
  add('OEBPS/text/ch1.xhtml', '''
<html><head><title>x</title><style>p{color:red}</style></head>
<body><h1>فصل <i>اول</i></h1><p>در زندگی زخم‌هایی هست.</p>
<img src="../images/cover.jpg"/><script>alert(1)</script></body></html>''');
  add('OEBPS/text/ch 2.xhtml', '<html><body><p>بدون عنوان</p></body></html>');
  add('OEBPS/text/empty.xhtml', '<html><body>  </body></html>');
  add('OEBPS/images/cover.jpg', 'JPEGDATA');
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('an EPUB yields its chapters in spine order with metadata', () {
    final book = parseEpub(epub());
    expect(book.title, 'بوف کور');
    expect(book.sections.map((s) => s.title), ['فصل اول', '']);
    expect(book.sections.first.html, contains('زخم‌هایی'));
    expect(book.sections.first.html, isNot(contains('alert')));
    expect(book.sections.first.html, isNot(contains('color:red')));
    expect(book.isRtl, isTrue);
    expect(utf8.decode(book.coverBytes!), 'JPEGDATA');
  });

  test('EPUB images resolve relative to their chapter', () {
    final book = parseEpub(epub());
    final chapter = book.sections.first;
    expect(
      utf8.decode(book.image(chapter, '../images/cover.jpg')!),
      'JPEGDATA',
    );
    expect(book.image(chapter, 'missing.png'), isNull);
    expect(book.image(chapter, 'https://example.com/a.png'), isNull);
  });

  test('an EPUB without a cover or a broken one is handled', () {
    expect(parseEpub(epub(withCover: false)).coverBytes, isNull);
    expect(
      () => parseEpub(Uint8List.fromList(ZipEncoder().encode(Archive()))),
      throwsFormatException,
    );
  });

  test('Markdown splits into chapters at top-level headings', () {
    final book = parseMarkdown(
      '# One\n\nintro **bold**\n\n```\n# not a heading\n```\n\n'
      '# Two\n\n## Sub\n\ntext',
    );
    expect(book.title, 'One');
    expect(book.sections.map((s) => s.title), ['One', 'Two']);
    expect(book.sections.first.html, contains('<strong>bold</strong>'));
    expect(book.sections.first.html, contains('# not a heading'));
    expect(book.isRtl, isFalse);
  });

  test('Markdown without headings is one section', () {
    final book = parseMarkdown('just a line');
    expect(book.sections, hasLength(1));
    expect(book.title, isNull);
  });

  test('plain text becomes escaped paragraphs in chunks', () {
    final text = List.generate(
      310,
      (i) => 'para <$i>\nsecond line',
    ).join('\n\n');
    final book = parsePlainText(text);
    expect(book.sections, hasLength(3));
    expect(book.sections.first.html, startsWith('<p>para &lt;0&gt;<br>second'));
    expect(parsePlainText('').sections, hasLength(1));
  });

  test('HTML keeps the body and reads the title', () {
    final book = parseHtml(
      '<html><head><title>A &amp; B</title><style>x{}</style></head>'
      '<body class="x"><p>سلام</p><script>bad()</script></body></html>',
    );
    expect(book.title, 'A & B');
    expect(book.sections.single.html, '<p>سلام</p>');
  });
}

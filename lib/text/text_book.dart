import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// File extensions of the reflowable formats, mapped to the format name
/// stored with a book.
const textFormats = {
  'epub': 'epub',
  'md': 'md',
  'markdown': 'md',
  'txt': 'txt',
  'html': 'html',
  'htm': 'html',
};

class TextSection {
  const TextSection({required this.title, required this.html, this.path = ''});

  /// Heading shown in the table of contents; empty if none was found.
  final String title;

  /// Body markup, without scripts or styles.
  final String html;

  /// Location inside an EPUB, for resolving the section's image paths.
  final String path;
}

/// A book in a reflowable format, reduced to HTML sections.
class TextBook {
  TextBook({required this.sections, this.title, this.coverBytes, this.archive});

  final List<TextSection> sections;

  /// Title from the file's own metadata, when it has one.
  final String? title;

  final Uint8List? coverBytes;

  /// The EPUB's zip, kept so images can be read when a section shows.
  final Archive? archive;

  /// Whether most of the text is in a right-to-left script.
  late final bool isRtl = _mostlyRtl(
    sections.take(3).map((s) => s.html).join(' '),
  );

  /// Bytes of an image [src] referenced from [section], or null when it
  /// isn't inside the book.
  Uint8List? image(TextSection section, String src) {
    final archive = this.archive;
    if (archive == null || src.startsWith(RegExp(r'[a-z]+:'))) return null;
    final path = p.url.normalize(
      p.url.join(p.url.dirname(section.path), Uri.decodeFull(src)),
    );
    return archive.findFile(path)?.content;
  }
}

/// Paragraphs per section when a plain file has to be cut into pieces so
/// that no single section is slow to lay out.
const _chunkSize = 150;

Future<TextBook> loadTextBook(File file, String format) async {
  switch (format) {
    case 'epub':
      return parseEpub(await file.readAsBytes());
    case 'md':
      return parseMarkdown(await _readText(file));
    case 'html':
      return parseHtml(await _readText(file));
    default:
      return parsePlainText(await _readText(file));
  }
}

Future<String> _readText(File file) async =>
    utf8.decode(await file.readAsBytes(), allowMalformed: true);

TextBook parsePlainText(String text) {
  final paragraphs = text
      .split(RegExp(r'\r?\n\s*\r?\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  const escape = HtmlEscape(HtmlEscapeMode.element);
  return TextBook(
    sections: [
      for (var i = 0; i < paragraphs.length; i += _chunkSize)
        TextSection(
          title: '',
          html: paragraphs
              .skip(i)
              .take(_chunkSize)
              .map(
                (s) => '<p>${escape.convert(s).replaceAll('\n', '<br>')}</p>',
              )
              .join(),
        ),
      if (paragraphs.isEmpty) const TextSection(title: '', html: ''),
    ],
  );
}

/// Splits at top-level headings so each chapter is its own section.
TextBook parseMarkdown(String text) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var inFence = false;
  for (final line in const LineSplitter().convert(text)) {
    if (line.trimLeft().startsWith('```')) inFence = !inFence;
    if (!inFence && line.startsWith('# ') && buffer.isNotEmpty) {
      parts.add(buffer.toString());
      buffer.clear();
    }
    buffer.writeln(line);
  }
  if (buffer.isNotEmpty || parts.isEmpty) parts.add(buffer.toString());

  final sections = [
    for (final part in parts)
      if (part.trim().isNotEmpty || parts.length == 1)
        TextSection(
          title: _firstHeading(part),
          html: md.markdownToHtml(
            part,
            extensionSet: md.ExtensionSet.gitHubFlavored,
          ),
        ),
  ];
  return TextBook(
    sections: sections,
    title: sections.first.title.isEmpty ? null : sections.first.title,
  );
}

String _firstHeading(String markdown) {
  final match = RegExp(
    r'^#{1,3}\s+(.+)$',
    multiLine: true,
  ).firstMatch(markdown);
  return match?.group(1)?.trim() ?? '';
}

TextBook parseHtml(String html) {
  final title = RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html)?.group(1);
  return TextBook(
    sections: [TextSection(title: '', html: _bodyOf(html))],
    title: title == null ? null : _plain(title),
  );
}

/// Reads an EPUB: the package document names the chapters in reading
/// order, and each chapter is an XHTML file inside the zip.
TextBook parseEpub(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  String text(String path) {
    final file = archive.findFile(path);
    if (file == null) throw FormatException('EPUB is missing $path');
    return utf8.decode(file.content, allowMalformed: true);
  }

  final container = XmlDocument.parse(text('META-INF/container.xml'));
  final opfPath = container
      .findAllElements('rootfile', namespaceUri: '*')
      .first
      .getAttribute('full-path')!;
  final opf = XmlDocument.parse(text(opfPath));
  final base = p.url.dirname(opfPath);
  String resolve(String href) =>
      p.url.normalize(p.url.join(base, Uri.decodeFull(href)));

  final items = <String, XmlElement>{
    for (final item in opf.findAllElements('item', namespaceUri: '*'))
      if (item.getAttribute('id') != null) item.getAttribute('id')!: item,
  };

  final sections = <TextSection>[];
  for (final ref in opf.findAllElements('itemref', namespaceUri: '*')) {
    final href = items[ref.getAttribute('idref')]?.getAttribute('href');
    if (href == null) continue;
    final path = resolve(href.split('#').first);
    final file = archive.findFile(path);
    if (file == null) continue;
    final raw = utf8.decode(file.content, allowMalformed: true);
    final body = _bodyOf(raw);
    if (_plain(body).isEmpty && !body.contains('<img')) continue;
    sections.add(TextSection(title: _headingOf(body), html: body, path: path));
  }
  if (sections.isEmpty) {
    throw const FormatException('EPUB has no readable text');
  }

  final coverId = opf
      .findAllElements('meta', namespaceUri: '*')
      .where((m) => m.getAttribute('name') == 'cover')
      .firstOrNull
      ?.getAttribute('content');
  final coverItem =
      items.values
          .where(
            (i) => (i.getAttribute('properties') ?? '').contains('cover-image'),
          )
          .firstOrNull ??
      items[coverId];
  final coverHref = coverItem?.getAttribute('href');
  final title = opf
      .findAllElements('title', namespaceUri: '*')
      .firstOrNull
      ?.innerText
      .trim();

  return TextBook(
    sections: sections,
    title: title == null || title.isEmpty ? null : title,
    coverBytes: coverHref == null
        ? null
        : archive.findFile(resolve(coverHref))?.content,
    archive: archive,
  );
}

String _bodyOf(String html) {
  final body = RegExp(
    r'<body[^>]*>(.*)</body>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html)?.group(1);
  return (body ?? html).replaceAll(
    RegExp(r'<(script|style)\b.*?</\1>', caseSensitive: false, dotAll: true),
    '',
  );
}

String _headingOf(String html) {
  final match = RegExp(
    r'<h[1-3][^>]*>(.*?)</h[1-3]>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  return match == null ? '' : _plain(match.group(1)!);
}

String _plain(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _mostlyRtl(String html) {
  final text = _plain(html);
  final sample = text.length > 3000 ? text.substring(0, 3000) : text;
  final rtl = RegExp(r'[֐-ࣿיִ-ﻼ]').allMatches(sample).length;
  final ltr = RegExp(r'[A-Za-z]').allMatches(sample).length;
  return rtl > ltr;
}

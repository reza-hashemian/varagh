import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../data/library.dart';
import '../data/models.dart';

/// Where the project lives; the about box links to its releases.
final releasesPage = Uri.parse(
  'https://github.com/reza-hashemian/varagh/releases',
);

/// What a link in a book points at: a web address for the browser, or a
/// file on this device, such as a video, for the program the system opens
/// that kind of file with. Null when it can't be made out, or names a file
/// that isn't there.
///
/// [folder] is where the book was added from: books are copied into the
/// library, so a link like `video.mp4` means that file beside the original.
Uri? resolveBookLink(String target, {String? folder}) {
  var text = target.trim();
  if (text.isEmpty) return null;
  // LaTeX writes \href{run:video.mp4} for "open this file".
  if (text.startsWith('run:')) text = text.substring(4);

  final uri = Uri.tryParse(text);
  // One letter is a Windows drive (C:\...), not a scheme.
  final scheme = uri == null || uri.scheme.length < 2 ? '' : uri.scheme;
  if (scheme.isNotEmpty && scheme != 'file') return uri;

  String path;
  try {
    path = scheme == 'file' ? uri!.toFilePath() : Uri.decodeFull(text);
  } catch (_) {
    path = text;
  }
  if (p.isRelative(path)) {
    if (folder == null) return null;
    path = p.normalize(p.join(folder, path));
  }
  return File(path).existsSync() ? Uri.file(path) : null;
}

/// Opens [target] from [book] outside the app. Returns false if it
/// couldn't be found or opened.
Future<bool> openBookLink(Library library, Book book, String target) async {
  final uri = resolveBookLink(target, folder: library.sourceFolderOf(book.id));
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

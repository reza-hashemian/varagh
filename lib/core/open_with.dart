import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../data/importer.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../text/text_book.dart';

/// Books handed to the app by the system's "Open with".
///
/// On Windows and Linux the file's path arrives as a launch argument.
/// macOS sends an open event and Android an intent, and both pass a path
/// over this channel; on Android it is of a copy the activity made in the
/// cache, as the app can't read the original by path.
const _channel = MethodChannel('app.varagh/open_with');

final _viaChannel = Platform.isAndroid || Platform.isMacOS;

/// The file the app was launched to open, where it comes by the channel.
Future<String?> initialOpenWithFile() async {
  if (!_viaChannel) return null;
  try {
    return await _channel.invokeMethod<String>('initialFile');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

/// Calls [onFile] for each file sent while the app is already running.
void listenForOpenWith(void Function(String path) onFile) {
  if (!_viaChannel) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'openFile') onFile(call.arguments as String);
  });
}

/// Adds the file at [path] to the library and returns its book. Throws if
/// it can't be read or isn't a supported type.
Future<Book> importOpenWithFile(Library library, String path) async {
  final file = File(path);
  try {
    final result = await importBook(
      library,
      name: p.basename(path),
      bytes: file.openRead().map(Uint8List.fromList),
      // On Android the file is a passing copy, not where the book lives.
      sourcePath: Platform.isAndroid ? null : path,
    );
    return result.book;
  } finally {
    // On Android the file is only the activity's copy of what was sent.
    if (Platform.isAndroid && file.existsSync()) file.deleteSync();
  }
}

/// Lists the app under "Open with" for books on Windows, where there is no
/// installer to do it. Done again only when the app has moved.
Future<void> registerOpenWith(Library library) async {
  if (!Platform.isWindows || !kReleaseMode) return;
  final exe = Platform.resolvedExecutable;
  if (library.setting('windows.openWith') == exe) return;

  final key = 'HKCU\\Software\\Classes\\Applications\\${p.basename(exe)}';
  Future<bool> add(List<String> args) async =>
      (await Process.run('reg', ['add', ...args, '/f'])).exitCode == 0;
  try {
    var done = await add([key, '/v', 'FriendlyAppName', '/d', 'Varagh']);
    done &= await add([
      '$key\\shell\\open\\command',
      '/ve',
      '/d',
      '"$exe" "%1"',
    ]);
    for (final extension in ['pdf', ...textFormats.keys]) {
      done &= await add([
        '$key\\SupportedTypes',
        '/v',
        '.$extension',
        '/d',
        '',
      ]);
    }
    if (done) library.setSetting('windows.openWith', exe);
  } catch (_) {
    // Without the registry entry the app just isn't offered for books.
  }
}

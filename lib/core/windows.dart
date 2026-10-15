import 'dart:io';

/// Extra windows: another copy of the app, started beside this one, that
/// shares its library. Lets books go on different monitors.

/// Launch argument that marks a copy as an extra window.
const extraWindowArg = '--window';

/// Launch argument naming the book an extra window opens on.
const _bookArg = '--book=';

/// Only desktops can run two copies of the app side by side.
final canOpenWindows =
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Starts another window of the app, opened on [bookId] if given. Returns
/// false if it couldn't be started.
Future<bool> openNewWindow({String? bookId}) async {
  if (!canOpenWindows) return false;
  try {
    // Detached, so it stays open when this window is closed.
    await Process.start(Platform.resolvedExecutable, [
      extraWindowArg,
      if (bookId != null) '$_bookArg$bookId',
    ], mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}

/// The book an extra window was asked to open, from its launch arguments.
String? launchBookId(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith(_bookArg)) return arg.substring(_bookArg.length);
  }
  return null;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_state.dart';

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// [key] with Ctrl, or with ⌘ on a Mac.
SingleActivator _command(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, control: !_isMac, meta: _isMac, shift: shift);

/// The keyboard shortcuts, in one place so the settings can list them.
abstract final class AppKeys {
  /// Works everywhere in the app.
  static final darkMode = _command(LogicalKeyboardKey.keyD);

  // In a book.
  static final pageDark = _command(LogicalKeyboardKey.keyD, shift: true);
  static final find = _command(LogicalKeyboardKey.keyF);
  static final goToPage = _command(LogicalKeyboardKey.keyG);
  static final highlight = _command(LogicalKeyboardKey.keyH);
  static final draw = _command(LogicalKeyboardKey.keyE);
  static final undo = _command(LogicalKeyboardKey.keyZ);
  static final autoHide = _command(LogicalKeyboardKey.keyH, shift: true);
  static final closeBook = _command(LogicalKeyboardKey.keyW);
  static const focusMode = SingleActivator(LogicalKeyboardKey.f11);

  // Handled by the PDF viewer itself; here only to be listed.
  static final zoomIn = _command(LogicalKeyboardKey.equal);
  static final zoomOut = _command(LogicalKeyboardKey.minus);
}

/// How [key] is written, such as "Ctrl+Shift+D" or "⇧⌘D".
String shortcutLabel(SingleActivator key) {
  final name = switch (key.trigger) {
    LogicalKeyboardKey.equal => '+',
    LogicalKeyboardKey.minus => '−',
    final other => other.keyLabel.toUpperCase(),
  };
  if (_isMac) {
    return '${key.shift ? '⇧' : ''}${key.meta ? '⌘' : ''}$name';
  }
  return [if (key.control) 'Ctrl', if (key.shift) 'Shift', name].join('+');
}

/// [label] followed by its shortcut, for a tooltip. Phones and tablets
/// rarely have a keyboard, so there it is just the label.
String withShortcut(String label, SingleActivator key) {
  final desktop = switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS => true,
    _ => false,
  };
  return desktop ? '$label  (${shortcutLabel(key)})' : label;
}

/// Shortcuts that work wherever the focus is, even on no field at all.
void registerAppShortcuts(AppState state) {
  HardwareKeyboard.instance.addHandler((event) {
    if (event is! KeyDownEvent) return false;
    if (AppKeys.darkMode.accepts(event, HardwareKeyboard.instance)) {
      state.toggleDark();
      return true;
    }
    return false;
  });
}

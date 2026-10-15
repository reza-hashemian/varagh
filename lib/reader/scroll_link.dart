import 'package:flutter/foundation.dart';

/// A reader whose scrolling can be linked to others on a desk.
///
/// Positions are in pages (or sections) from the start of the book: 3.5 is
/// halfway down the fourth page.
abstract interface class LinkedReader {
  /// Where the reader is now; null until its book has loaded.
  double? get linkedPosition;

  /// Goes to [position], keeping its own zoom, and returns where it landed,
  /// which differs at the ends of the book.
  double follow(double position);
}

/// Scrolls the books of a desk together while it is on: when one moves
/// by some pages, the others move by as many from wherever they are, so
/// a text and its translation stay side by side.
class ScrollLink extends ChangeNotifier {
  final _readers = <LinkedReader>{};

  /// Where each reader was last seen or sent.
  final _last = <LinkedReader, double>{};

  var _on = false;
  bool get isOn => _on;

  void toggle() {
    _on = !_on;
    _last.clear();
    if (_on) _readers.forEach(_markWhere);
    notifyListeners();
  }

  void join(LinkedReader reader) {
    _readers.add(reader);
    if (_on) _markWhere(reader);
  }

  void leave(LinkedReader reader) {
    _readers.remove(reader);
    _last.remove(reader);
  }

  void _markWhere(LinkedReader reader) {
    final position = reader.linkedPosition;
    if (position != null) _last[reader] = position;
  }

  /// Tells the link that [reader] has been moved to [position].
  void moved(LinkedReader reader, double position) {
    if (!_on) return;
    final last = _last[reader];
    _last[reader] = position;
    // A reader's first report only says where it starts.
    if (last == null) return;
    final step = position - last;
    // Also what comes back from a reader that was just made to follow.
    if (step.abs() < 1e-4) return;
    for (final other in _readers) {
      if (other == reader) continue;
      final from = _last[other] ?? other.linkedPosition;
      if (from == null) continue;
      _last[other] = other.follow(from + step);
    }
  }
}

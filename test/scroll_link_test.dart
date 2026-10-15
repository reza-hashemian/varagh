import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/reader/scroll_link.dart';

/// A book of [length] pages that goes wherever it is sent, as far as its
/// ends allow, and reports moves made to it like a real reader would.
class _Reader implements LinkedReader {
  _Reader(this.link, this.length, this.at);

  final ScrollLink link;
  final double length;
  double at;
  var following = false;

  @override
  double? get linkedPosition => at;

  @override
  double follow(double position) {
    following = true;
    at = position.clamp(0, length);
    following = false;
    return at;
  }

  /// The reader scrolls by hand.
  void scrollTo(double position) {
    at = position;
    if (!following) link.moved(this, at);
  }
}

void main() {
  late ScrollLink link;
  late _Reader a, b;

  setUp(() {
    link = ScrollLink();
    a = _Reader(link, 100, 10);
    b = _Reader(link, 100, 40);
    link
      ..join(a)
      ..join(b);
  });

  test('does nothing until turned on', () {
    a.scrollTo(12);
    expect(b.at, 40);
  });

  test('moves the others by as many pages, from where they are', () {
    link.toggle();
    a.scrollTo(12.5);
    expect(b.at, 42.5);
    // Either one can lead.
    b.scrollTo(41);
    expect(a.at, 11);
  });

  test('a book held at its end slips rather than pulling back', () {
    final short = _Reader(link, 5, 4);
    link
      ..join(short)
      ..toggle();
    a.scrollTo(13);
    expect(short.at, 5);
    expect(b.at, 43);
    a.scrollTo(12);
    expect(short.at, 4);
  });

  test('turning it off and on again starts from where each one is', () {
    link.toggle();
    link.toggle();
    a.scrollTo(30);
    link.toggle();
    a.scrollTo(31);
    expect(b.at, 41);
  });

  test('a book that left is no longer moved', () {
    link
      ..toggle()
      ..leave(b);
    a.scrollTo(20);
    expect(b.at, 40);
  });
}

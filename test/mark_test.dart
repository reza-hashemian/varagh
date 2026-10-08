import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/draw/mark.dart';
import 'package:varagh/draw/mark_painter.dart';

void main() {
  const stroke = Mark(
    tool: MarkTool.pen,
    color: Color(0xFF1F6FEB),
    width: 2,
    points: [0, 0, 100, 0],
  );

  test('marks survive a round trip through JSON', () {
    const text = Mark(
      tool: MarkTool.text,
      color: Color(0xFFE5383B),
      width: 2.4,
      points: [10, 20],
      text: 'سلام',
    );
    final back = Mark.decodeAll(Mark.encodeAll([stroke, text]));
    expect(back, hasLength(2));
    expect(back[0].tool, MarkTool.pen);
    expect(back[0].color, const Color(0xFF1F6FEB));
    expect(back[0].points, [0, 0, 100, 0]);
    expect(back[1].text, 'سلام');
    expect(Mark.decodeAll(''), isEmpty);
    expect(Mark.decodeAll('not json'), isEmpty);
    expect(Mark.decodeAll('[{"tool":"laser","points":[]}, 5]'), isEmpty);
  });

  test('a stroke is hit near its line and missed away from it', () {
    expect(stroke.hit(50, 3, 4), isTrue);
    expect(stroke.hit(50, 9, 4), isFalse);
    expect(stroke.hit(104, 0, 4), isTrue);
    expect(stroke.hit(120, 0, 4), isFalse);
  });

  test('a marker is broader than a pen of the same setting', () {
    final marker = Mark(
      tool: MarkTool.marker,
      color: stroke.color,
      width: 2,
      points: stroke.points,
    );
    expect(marker.hit(50, 8, 4), isTrue);
    expect(stroke.hit(50, 8, 4), isFalse);
  });

  test('shapes are hit inside their box', () {
    const box = Mark(
      tool: MarkTool.rect,
      color: Color(0xFF000000),
      width: 1,
      points: [10, 10, 60, 40],
    );
    expect(box.hit(30, 25, 2), isTrue);
    expect(box.hit(80, 25, 2), isFalse);
  });

  test('text direction follows its first letter', () {
    expect(startsRtl('سلام world'), isTrue);
    expect(startsRtl('12 hello سلام'), isFalse);
    expect(startsRtl('۱۲۳'), isFalse);
  });
}

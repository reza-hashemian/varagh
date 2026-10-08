import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/draw/mark.dart';
import 'package:varagh/draw/mark_painter.dart';

/// A slow hand-drawn curve as a mouse reports it: whole pixels only.
List<Offset> mousePath() => [
  for (var i = 0; i <= 420; i++)
    Offset(
      (20 + i).roundToDouble(),
      (60 + 34 * math.sin(i / 55) + i * 0.12).roundToDouble(),
    ),
];

Mark stroke(MarkTool tool, {bool weighted = false}) {
  final sampler = StrokeSampler(minDistance: 3.2);
  final path = mousePath();
  for (final point in path) {
    sampler.add(point.dx, point.dy);
  }
  sampler.finish(path.last.dx, path.last.dy);
  return Mark(
    tool: tool,
    color: const Color(0xFF1F6FEB),
    width: 2.4,
    points: sampler.points,
    widths: weighted ? sampler.widths : null,
  );
}

void main() {
  test('sampling a pixel staircase leaves a smooth, sparse line', () {
    final raw = mousePath();
    final sampler = StrokeSampler(minDistance: 3.2);
    for (final point in raw) {
      sampler.add(point.dx, point.dy);
    }
    final p = sampler.points;
    expect(p.length ~/ 2, lessThan(raw.length ~/ 2));
    expect(sampler.widths.length, p.length ~/ 2);

    // Direction changes between consecutive segments stay gentle: no
    // right-angle steps survive.
    var sharpest = 0.0;
    for (var i = 2; i + 3 < p.length; i += 2) {
      final a = math.atan2(p[i + 1] - p[i - 1], p[i] - p[i - 2]);
      final b = math.atan2(p[i + 3] - p[i + 1], p[i + 2] - p[i]);
      sharpest = math.max(sharpest, (a - b).abs());
    }
    expect(sharpest, lessThan(0.5));

    // And it stays on the path that was drawn.
    for (var i = 0; i + 1 < p.length; i += 2) {
      final x = p[i];
      final ideal = 60 + 34 * math.sin((x - 20) / 55) + (x - 20) * 0.12;
      expect((p[i + 1] - ideal).abs(), lessThan(3.5));
    }
  });

  test('the stroke ends where the pointer was lifted', () {
    final sampler = StrokeSampler(minDistance: 3.2)..add(0, 0);
    for (var x = 1.0; x <= 50; x++) {
      sampler.add(x, 0);
    }
    sampler.finish(50, 0);
    expect(sampler.points[sampler.points.length - 2], 50);
  });

  test('a slower stroke is heavier, and pressure overrides speed', () {
    final slow = StrokeSampler(minDistance: 1)..add(0, 0);
    final fast = StrokeSampler(minDistance: 1)..add(0, 0);
    for (var i = 1; i <= 40; i++) {
      slow.add(i * 3.0, 0);
      fast.add(i * 30.0, 0);
    }
    expect(slow.widths.last, greaterThan(fast.widths.last));
    expect(slow.hasPressure, isFalse);

    final pressed = StrokeSampler(minDistance: 1)..add(0, 0, pressure: 1);
    for (var i = 1; i <= 40; i++) {
      pressed.add(i * 30.0, 0, pressure: 1);
    }
    expect(pressed.hasPressure, isTrue);
    expect(pressed.widths.last, greaterThan(slow.widths.last));
  });

  test('per-point weights survive saving', () {
    final mark = stroke(MarkTool.brush, weighted: true);
    final back = Mark.decodeAll(Mark.encodeAll([mark])).single;
    expect(back.tool, MarkTool.brush);
    expect(back.widths, hasLength(mark.points.length ~/ 2));
    expect(back.points.first, closeTo(mark.points.first, 0.01));
  });

  test('every pen renders without error', () async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const scale = 2.0;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 920, 1180),
      Paint()..color = const Color(0xFFFFFEFA),
    );

    // Top row: the raw mouse path joined point to point, for comparison.
    final raw = mousePath();
    canvas.drawPath(
      Path()..addPolygon([for (final p in raw) p * scale], false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * scale
        ..color = const Color(0xFF1D1D1F),
    );

    var row = 1;
    for (final (tool, weighted) in [
      (MarkTool.pen, false),
      (MarkTool.fountain, false),
      (MarkTool.brush, true),
      (MarkTool.pencil, false),
      (MarkTool.marker, false),
    ]) {
      final dy = row++ * 95.0;
      paintMark(
        canvas,
        stroke(tool, weighted: weighted),
        (x, y) => Offset(x * scale, (y + dy) * scale),
        scale,
      );
    }

    final image = await recorder.endRecording().toImage(920, 1180);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    expect(bytes, isNotNull);
    final out = Platform.environment['STROKE_PNG'];
    if (out != null) File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

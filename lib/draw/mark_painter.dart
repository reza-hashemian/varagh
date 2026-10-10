import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'mark.dart';

/// Whether the first letter of [text] is in a right-to-left script. Digits
/// and punctuation don't count, as they take the direction around them.
bool startsRtl(String text) {
  final strong = RegExp('[A-Za-z֐-ٟ٪-ۯۺ-ࣿיִ-ﻼ]').firstMatch(text)?.group(0);
  return strong != null && !RegExp('[A-Za-z]').hasMatch(strong);
}

/// Paint that darkens an opaque backdrop the way a see-through [color]
/// would under multiply blending.
///
/// Multiply itself reads the picture back for every shape drawn with it,
/// and with a page full of highlights those copies pile up and smear the
/// page while it scrolls. Over an opaque backdrop, modulating by the color
/// mixed with white comes to exactly the same result without reading back.
Paint highlighterPaint(Color color) => Paint()
  ..blendMode = BlendMode.modulate
  ..color = Color.lerp(
    const Color(0xFFFFFFFF),
    color.withValues(alpha: 1),
    color.a,
  )!;

/// Draws [mark]. [at] maps a page point to canvas coordinates and [unit] is
/// how many canvas pixels one page point covers. [onPaper] says the canvas
/// already holds an opaque page for a highlighter to darken.
void paintMark(
  Canvas canvas,
  Mark mark,
  Offset Function(double x, double y) at,
  double unit, {
  String fontFamily = 'Vazirmatn',
  bool onPaper = true,
}) {
  final p = mark.points;
  if (p.length < 2) return;

  if (mark.tool == MarkTool.text) {
    final rtl = startsRtl(mark.text);
    final painter = TextPainter(
      text: TextSpan(
        text: mark.text,
        style: TextStyle(
          color: mark.color,
          fontSize: mark.textSize * unit,
          fontFamily: fontFamily,
          height: 1.5,
        ),
      ),
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    )..layout();
    final anchor = at(p[0], p[1]);
    // Right-to-left text hangs from its anchor to the left.
    painter.paint(canvas, rtl ? anchor.translate(-painter.width, 0) : anchor);
    painter.dispose();
    return;
  }

  if (mark.isFreehand) {
    _paintStroke(canvas, mark, at, unit, onPaper);
    return;
  }

  if (p.length < 4) return;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.6, mark.drawnWidth * unit)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = mark.color;
  final a = at(p[0], p[1]), b = at(p[2], p[3]);
  switch (mark.tool) {
    case MarkTool.rect:
      canvas.drawRect(Rect.fromPoints(a, b), paint);
    case MarkTool.ellipse:
      canvas.drawOval(Rect.fromPoints(a, b), paint);
    case MarkTool.arrow:
      canvas.drawLine(a, b, paint);
      final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      final head = math.max(8 * unit, paint.strokeWidth * 3.5);
      for (final turn in const [2.6, -2.6]) {
        canvas.drawLine(
          b,
          b + Offset(math.cos(angle + turn), math.sin(angle + turn)) * head,
          paint,
        );
      }
    default:
      canvas.drawLine(a, b, paint);
  }
}

/// How far smoothing may move a point of a stroke, in page points.
const _relaxReach = 0.4;

void _paintStroke(
  Canvas canvas,
  Mark mark,
  Offset Function(double x, double y) at,
  double unit,
  bool onPaper,
) {
  final p = mark.points;
  final points = relaxStroke([
    for (var i = 0; i + 1 < p.length; i += 2) at(p[i], p[i + 1]),
  ], _relaxReach * unit);
  final width = math.max(0.6, mark.drawnWidth * unit);

  if (points.length == 1) {
    canvas.drawCircle(points.first, width / 2, Paint()..color = mark.color);
    return;
  }

  switch (mark.tool) {
    case MarkTool.marker:
      // A highlighter: broad, see-through, and it darkens what is under it
      // instead of covering it.
      final color = mark.color.withValues(alpha: 0.38);
      canvas.drawPath(
        _curve(points),
        (onPaper ? highlighterPaint(color) : (Paint()..color = color))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.square,
      );
    case MarkTool.pencil:
      // Graphite: a soft core with two fainter, slightly wandering lines
      // beside it gives the grain of a pencil on paper.
      final core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = mark.color.withValues(alpha: 0.55);
      canvas.drawPath(_curve(points), core);
      core
        ..strokeWidth = width * 0.55
        ..color = mark.color.withValues(alpha: 0.3);
      for (final phase in const [0.0, 2.1]) {
        canvas.drawPath(
          _curve([
            for (var i = 0; i < points.length; i++)
              points[i] +
                  _normal(points, i) *
                      (math.sin(i * 1.7 + phase) * width * 0.42),
          ]),
          core,
        );
      }
    case MarkTool.brush:
    case MarkTool.fountain:
      _paintShaped(canvas, mark, points, width);
    default:
      // A pen is even unless a stylus pressed harder in places.
      if (mark.widths != null) {
        _paintShaped(canvas, mark, points, width);
      } else {
        canvas.drawPath(
          _curve(points),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = mark.color,
        );
      }
  }
}

/// Evens out the last of the wobble a whole-pixel pointer leaves, by
/// pulling each point toward its neighbors twice. No point moves further
/// than [reach], so the turns of small handwriting stay as drawn, and the
/// ends stay put, so the stroke still starts and stops where it was drawn.
List<Offset> relaxStroke(List<Offset> points, double reach) {
  if (points.length < 4) return points;
  var current = points;
  for (var pass = 0; pass < 2; pass++) {
    current = [
      current.first,
      for (var i = 1; i + 1 < current.length; i++)
        (current[i - 1] + current[i] * 2 + current[i + 1]) / 4,
      current.last,
    ];
  }
  return [
    for (var i = 0; i < points.length; i++)
      switch (current[i] - points[i]) {
        final shift when shift.distance > reach =>
          points[i] + shift / shift.distance * reach,
        _ => current[i],
      },
  ];
}

/// Unit normal to the stroke at point [i].
Offset _normal(List<Offset> points, int i) {
  final before = points[i == 0 ? 0 : i - 1];
  final after = points[i == points.length - 1 ? i : i + 1];
  final tangent = after - before;
  final length = tangent.distance;
  return length == 0
      ? const Offset(0, 1)
      : Offset(-tangent.dy / length, tangent.dx / length);
}

/// Control points of the Catmull-Rom curve segment from point [i] to the
/// next, as a cubic Bézier. The curve passes through every sample, so the
/// stroke stays where it was drawn while its corners round off.
(Offset, Offset) _controls(List<Offset> points, int i) {
  final p0 = points[i == 0 ? 0 : i - 1];
  final p1 = points[i];
  final p2 = points[i + 1];
  final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
  return (p1 + (p2 - p0) / 6, p2 - (p3 - p1) / 6);
}

Path _curve(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i + 1 < points.length; i++) {
    final (c1, c2) = _controls(points, i);
    final end = points[i + 1];
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
  }
  return path;
}

/// Nib angle of the fountain pen, measured on screen.
const _nibAngle = -math.pi / 4;

/// Draws a stroke whose width changes along its length, as a filled
/// outline: the centerline is resampled every couple of pixels along its
/// curve, and the outline runs half a width to each side of it.
void _paintShaped(Canvas canvas, Mark mark, List<Offset> points, double width) {
  final weights = mark.widths;
  final centers = <Offset>[points.first];
  final radii = <double>[];
  double weightAt(int i) =>
      weights == null || i >= weights.length ? 1.0 : weights[i];
  // A pen only breathes a little with pressure; a brush swings widely.
  double radius(double weight) => switch (mark.tool) {
    MarkTool.brush => width / 2 * weight,
    MarkTool.fountain => width / 2 * (0.75 + 0.3 * weight),
    _ => width / 2 * (0.6 + 0.5 * weight),
  };
  radii.add(radius(weightAt(0)));

  for (var i = 0; i + 1 < points.length; i++) {
    final (c1, c2) = _controls(points, i);
    final a = points[i], b = points[i + 1];
    final steps = ((b - a).distance / 2.5).ceil().clamp(1, 16);
    for (var step = 1; step <= steps; step++) {
      final t = step / steps, u = 1 - t;
      centers.add(
        a * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            b * (t * t * t),
      );
      radii.add(radius(weightAt(i) * u + weightAt(i + 1) * t));
    }
  }

  final count = centers.length;
  if (mark.tool == MarkTool.fountain) {
    // A broad nib held at a fixed angle: strokes along the nib's edge are
    // hairlines, strokes across it are full width.
    for (var i = 0; i < count; i++) {
      final tangent =
          centers[i == count - 1 ? i : i + 1] - centers[i == 0 ? 0 : i - 1];
      final across = math
          .sin(math.atan2(tangent.dy, tangent.dx) - _nibAngle)
          .abs();
      radii[i] *= 0.28 + 0.72 * across;
    }
  } else if (mark.tool == MarkTool.brush) {
    // The brush lands and lifts: it swells in over the first stretch and
    // trails off to a point at the end.
    final lead = math.min(8, count ~/ 3), tail = math.min(14, count ~/ 2);
    for (var i = 0; i < lead; i++) {
      radii[i] *= 0.35 + 0.65 * (i / lead);
    }
    for (var i = 0; i < tail; i++) {
      radii[count - 1 - i] *= 0.12 + 0.88 * (i / tail);
    }
  }

  final left = <Offset>[], right = <Offset>[];
  for (var i = 0; i < count; i++) {
    final offset = _normal(centers, i) * math.max(0.3, radii[i]);
    left.add(centers[i] + offset);
    right.add(centers[i] - offset);
  }
  final paint = Paint()..color = mark.color;
  canvas.drawPath(
    Path()
      ..addPolygon([...left, ...right.reversed], true)
      ..fillType = PathFillType.nonZero,
    paint,
  );
  // Round ends, and a round patch where the stroke doubles back sharply,
  // since the outline alone would pinch there.
  canvas.drawCircle(centers.first, math.max(0.3, radii.first), paint);
  canvas.drawCircle(centers.last, math.max(0.3, radii.last), paint);
  for (var i = 1; i + 1 < count; i++) {
    final a = centers[i] - centers[i - 1], b = centers[i + 1] - centers[i];
    if (a.dx * b.dx + a.dy * b.dy < 0) {
      canvas.drawCircle(centers[i], math.max(0.3, radii[i]), paint);
    }
  }
}

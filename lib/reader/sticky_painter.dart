import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../draw/mark_painter.dart';
import 'highlight_colors.dart';

/// Width of a sticky note in PDF points, so it keeps its size relative to
/// the page at any zoom.
const stickyWidth = 132.0;
const _padding = 8.0;
const _minHeight = 44.0;

/// Lays out a sticky note's text at [unit] pixels per PDF point.
TextPainter _text(Annotation sticky, double unit) => TextPainter(
  text: TextSpan(
    text: sticky.note,
    style: TextStyle(
      color: const Color(0xFF2B2A26),
      fontSize: 8.5 * unit,
      height: 1.5,
      fontFamily: appFontFamily,
    ),
  ),
  textDirection: startsRtl(sticky.note) ? TextDirection.rtl : TextDirection.ltr,
)..layout(maxWidth: (stickyWidth - 2 * _padding) * unit);

/// Height of a sticky note in PDF points; it grows with its text. Laying
/// out text is costly, so callers that ask often should keep the answer.
double stickyHeight(Annotation sticky) {
  final painter = _text(sticky, 1);
  final laidOut = painter.height + 2 * _padding;
  painter.dispose();
  return laidOut < _minHeight ? _minHeight : laidOut;
}

/// Draws a sticky note [height] PDF points tall with its top corner at
/// [corner], at [unit] pixels per PDF point.
void paintSticky(
  Canvas canvas,
  Annotation sticky,
  Offset corner,
  double unit, {
  required double height,
}) {
  final rect = corner & Size(stickyWidth * unit, height * unit);
  final paper = Color.lerp(sticky.color.swatch, Colors.white, 0.42)!;
  final fold = 11 * unit;
  canvas.drawRect(
    rect.shift(Offset(0, 2 * unit)),
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * unit),
  );
  // The sheet with its bottom corner turned up, as a real one curls.
  canvas.drawPath(
    Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - fold)
      ..lineTo(rect.right - fold, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close(),
    Paint()..color = paper,
  );
  canvas.drawPath(
    Path()
      ..moveTo(rect.right, rect.bottom - fold)
      ..lineTo(rect.right - fold, rect.bottom - fold)
      ..lineTo(rect.right - fold, rect.bottom)
      ..close(),
    Paint()..color = Color.lerp(sticky.color.swatch, Colors.black, 0.18)!,
  );
  final painter = _text(sticky, unit);
  final padding = _padding * unit;
  painter.paint(
    canvas,
    Offset(
      startsRtl(sticky.note)
          ? rect.right - padding - painter.width
          : rect.left + padding,
      rect.top + padding,
    ),
  );
  painter.dispose();
}

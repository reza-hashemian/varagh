import 'package:flutter/material.dart';

import '../data/models.dart';
import '../draw/mark.dart';
import '../draw/mark_painter.dart';

/// Size of a notebook page in points (A4), the same unit PDF pages use, so
/// pen widths look alike on both.
const notebookPageSize = Size(595, 842);

const _paperColor = Color(0xFFFFFEFA);
const _ruleColor = Color(0xFFC3D3EA);

/// Paints a notebook page: its paper and everything on it.
class PagePainter extends CustomPainter {
  const PagePainter({required this.paper, required this.marks});

  final PaperStyle paper;
  final List<Mark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / notebookPageSize.width;
    // Drawn into a layer of its own: on some graphics drivers shapes drawn
    // straight onto the window get no edge smoothing and come out jagged,
    // while a layer is always smoothed.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = _paperColor);
    _paintRuling(canvas, size, unit);

    Offset at(double x, double y) => Offset(x * unit, y * unit);
    for (final mark in marks) {
      paintMark(canvas, mark, at, unit);
    }
    canvas.restore();
  }

  void _paintRuling(Canvas canvas, Size size, double unit) {
    const step = 24.0, margin = 36.0;
    final rule = Paint()
      ..color = _ruleColor
      ..strokeWidth = (0.6 * unit).clamp(0.5, 1.5);
    switch (paper) {
      case PaperStyle.blank:
        break;
      case PaperStyle.lined:
        for (
          var y = margin * 2;
          y < notebookPageSize.height - margin;
          y += step
        ) {
          canvas.drawLine(
            Offset(margin * unit, y * unit),
            Offset(size.width - margin * unit, y * unit),
            rule,
          );
        }
      case PaperStyle.grid:
        for (var y = step; y < notebookPageSize.height; y += step) {
          canvas.drawLine(
            Offset(0, y * unit),
            Offset(size.width, y * unit),
            rule,
          );
        }
        for (var x = step; x < notebookPageSize.width; x += step) {
          canvas.drawLine(
            Offset(x * unit, 0),
            Offset(x * unit, size.height),
            rule,
          );
        }
      case PaperStyle.dots:
        final dot = Paint()..color = _ruleColor;
        for (var y = step; y < notebookPageSize.height; y += step) {
          for (var x = step; x < notebookPageSize.width; x += step) {
            canvas.drawCircle(Offset(x * unit, y * unit), 1.1 * unit, dot);
          }
        }
    }
  }

  @override
  bool shouldRepaint(PagePainter old) =>
      old.paper != paper || old.marks != marks;
}

/// Paints only the mark under the pen, over the finished page.
class LiveMarkPainter extends CustomPainter {
  const LiveMarkPainter(this.mark);

  final Mark? mark;

  @override
  void paint(Canvas canvas, Size size) {
    final mark = this.mark;
    if (mark == null) return;
    final unit = size.width / notebookPageSize.width;
    // In a layer for the same reason as the page: smooth edges everywhere.
    canvas.saveLayer(Offset.zero & size, Paint());
    paintMark(canvas, mark, (x, y) => Offset(x * unit, y * unit), unit);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiveMarkPainter old) => old.mark != mark;
}

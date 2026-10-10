import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

/// What a mark on a page is: a freehand stroke of some pen, a shape, or a
/// line of typed text.
enum MarkTool {
  /// Even line, like a gel pen.
  pen,

  /// Broad-nib pen: thick on some strokes and thin on others, by direction.
  fountain,

  /// Soft brush: swells when slow or pressed, thins when fast, tapers out.
  brush,

  /// Grainy, slightly see-through line.
  pencil,

  /// Highlighter.
  marker,
  line,
  arrow,
  rect,
  ellipse,
  text,
}

/// Stroke widths the tool picker offers, in page points.
const markWidths = [1.2, 2.4, 4.5];

/// Ink colors the tool picker offers.
const markColors = [
  Color(0xFF1D1D1F),
  Color(0xFF8E8E93),
  Color(0xFFE5383B),
  Color(0xFFF28C28),
  Color(0xFFF2C200),
  Color(0xFF2FA84F),
  Color(0xFF1F6FEB),
  Color(0xFF8A4FD8),
];

/// One thing drawn on a page. Coordinates are page points with the origin
/// wherever the page's own space puts it, so the same mark works on a PDF
/// page (origin bottom left) and on a notebook page (origin top left).
class Mark {
  const Mark({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.widths,
    this.text = '',
  });

  final MarkTool tool;
  final Color color;

  /// Stroke width in page points. For text it sets the type size.
  final double width;

  /// x, y pairs. A freehand stroke lists every sample; a shape has its two
  /// corners; text has its anchor.
  final List<double> points;

  /// How heavy the stroke is at each point, as a multiple of [width]: one
  /// value per x, y pair, from stylus pressure or drawing speed. Null for
  /// an even stroke.
  final List<double>? widths;

  final String text;

  bool get isFreehand =>
      tool == MarkTool.pen ||
      tool == MarkTool.fountain ||
      tool == MarkTool.brush ||
      tool == MarkTool.pencil ||
      tool == MarkTool.marker;

  /// Type size of a text mark, in page points.
  double get textSize => 9 + width * 3;

  /// Width the stroke is actually drawn at: a marker is a broad chisel, a
  /// pencil a little finer than a pen.
  double get drawnWidth => switch (tool) {
    MarkTool.marker => width * 5,
    MarkTool.brush => width * 2.4,
    MarkTool.fountain => width * 1.5,
    MarkTool.pencil => width * 0.8,
    _ => width,
  };

  /// A copy with other points; pass [widths] with them when the stroke has
  /// per-point weights, since the two lists go together.
  Mark copyWith({List<double>? points, List<double>? widths, String? text}) =>
      Mark(
        tool: tool,
        color: color,
        width: width,
        points: points ?? this.points,
        widths: widths ?? (points == null ? this.widths : null),
        text: text ?? this.text,
      );

  /// Whether ([x], [y]) is on the mark, within [slop] page points.
  bool hit(double x, double y, double slop) {
    if (points.length < 2) return false;
    final reach = slop + drawnWidth / 2;
    switch (tool) {
      case MarkTool.text:
        // Text grows right and down from its anchor in either y direction,
        // so the test is generous around it.
        final lines = '\n'.allMatches(text).length + 1;
        final longest = text
            .split('\n')
            .fold<int>(0, (m, l) => math.max(m, l.length));
        final w = longest * textSize * 0.6, h = lines * textSize * 1.5;
        return (x - points[0]).abs() <= w + slop &&
            (y - points[1]).abs() <= h + slop;
      case MarkTool.rect:
      case MarkTool.ellipse:
        if (points.length < 4) return false;
        final left = math.min(points[0], points[2]) - reach;
        final right = math.max(points[0], points[2]) + reach;
        final low = math.min(points[1], points[3]) - reach;
        final high = math.max(points[1], points[3]) + reach;
        return x >= left && x <= right && y >= low && y <= high;
      default:
        for (var i = 0; i + 3 < points.length; i += 2) {
          if (distanceToSegment(
                x,
                y,
                points[i],
                points[i + 1],
                points[i + 2],
                points[i + 3],
              ) <=
              reach) {
            return true;
          }
        }
        return false;
    }
  }

  Map<String, Object> toJson() => {
    'tool': tool.name,
    'color': color.toARGB32(),
    'width': width,
    // Two decimals of a point is finer than any screen shows and keeps
    // saved strokes small.
    'points': [for (final v in points) (v * 100).round() / 100],
    if (widths != null) 'w': [for (final v in widths!) (v * 100).round() / 100],
    if (text.isNotEmpty) 'text': text,
  };

  static Mark? fromJson(Object? json) {
    if (json is! Map) return null;
    final tool = MarkTool.values.asNameMap()[json['tool']];
    final points = json['points'];
    if (tool == null || points is! List) return null;
    return Mark(
      tool: tool,
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF1D1D1F),
      width: (json['width'] as num?)?.toDouble() ?? markWidths[1],
      points: [for (final v in points) (v as num).toDouble()],
      widths: switch (json['w']) {
        final List w when w.length * 2 == points.length => [
          for (final v in w) (v as num).toDouble(),
        ],
        _ => null,
      },
      text: json['text'] as String? ?? '',
    );
  }

  static String encodeAll(List<Mark> marks) =>
      jsonEncode([for (final mark in marks) mark.toJson()]);

  static List<Mark> decodeAll(String json) {
    if (json.isEmpty) return [];
    try {
      return [
        for (final item in jsonDecode(json) as List) ?Mark.fromJson(item),
      ];
    } on FormatException {
      return [];
    }
  }
}

double distanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax, dy = by - ay;
  final length2 = dx * dx + dy * dy;
  final t = length2 == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / length2).clamp(0.0, 1.0);
  final cx = ax + t * dx - px, cy = ay + t * dy - py;
  return math.sqrt(cx * cx + cy * cy);
}

/// Turns raw pointer positions into the points of a smooth stroke.
///
/// A finger or stylus is followed exactly, so the small turns of
/// handwriting keep their shape. A mouse reports whole pixels, so a slow
/// stroke sampled at every event is a staircase; it is followed with a
/// filter that lags while the mouse moves slowly, which is where the steps
/// show. The sampler also records how heavy the stroke is at each point:
/// from stylus pressure when there is one, otherwise from speed, slower
/// being heavier.
class StrokeSampler {
  StrokeSampler({required this.pixel, this.precise = false});

  /// Size of a screen pixel in page points.
  final double pixel;

  /// Whether positions come finer than a pixel, as from a finger or stylus.
  final bool precise;

  /// Least spacing between kept points, in screen pixels. Wider for a
  /// mouse, to span the steps of its whole pixels.
  double get _spacing => precise ? 1.5 : 3;

  /// Least length, in screen pixels, of the two arms of a turn for it to
  /// count as one; shorter than this is jitter.
  static const _turnArm = 0.6;

  final points = <double>[];
  final widths = <double>[];
  var _weight = 0.9;

  /// Where the pointer last was, and where the filter following it is.
  var _rawX = 0.0, _rawY = 0.0, _x = 0.0, _y = 0.0;

  /// Where the stroke would turn if it changed direction now: the filter's
  /// position one arm back.
  var _turnX = 0.0, _turnY = 0.0;

  /// Whether any point came with real stylus pressure.
  bool hasPressure = false;

  /// Feeds a pointer position. Returns whether a point was added.
  bool add(double x, double y, {double? pressure}) {
    if (points.isEmpty) {
      points.addAll([x, y]);
      _rawX = _x = _turnX = x;
      _rawY = _y = _turnY = y;
      if (pressure != null) hasPressure = true;
      _weight = pressure == null ? 0.9 : 0.3 + pressure * 1.1;
      widths.add(_weight);
      return true;
    }
    // Events arrive at a steady rate, so distance per event is speed.
    final step =
        math.sqrt((x - _rawX) * (x - _rawX) + (y - _rawY) * (y - _rawY)) /
        pixel;
    _rawX = x;
    _rawY = y;
    // Up to a pixel per event the filter closes a third of the gap; from
    // five pixels on it is on the pointer.
    final follow = precise ? 1.0 : (0.3 + 0.7 * (step - 1) / 4).clamp(0.3, 1.0);
    _x += (x - _x) * follow;
    _y += (y - _y) * follow;

    final double target;
    if (pressure != null) {
      hasPressure = true;
      target = 0.3 + pressure * 1.1;
    } else {
      target = (1.3 - step / 50).clamp(0.4, 1.25);
    }
    _weight = _weight * 0.72 + target * 0.28;

    final lastX = points[points.length - 2], lastY = points[points.length - 1];
    var added = false;
    // A sharp turn is kept as a point of its own. Spacing alone would step
    // over it and round the corner off.
    final ax = _turnX - lastX, ay = _turnY - lastY;
    final bx = _x - _turnX, by = _y - _turnY;
    final a = math.sqrt(ax * ax + ay * ay), b = math.sqrt(bx * bx + by * by);
    final arm = _turnArm * pixel;
    if (a >= arm && b >= arm && ax * bx + ay * by < 0.5 * a * b) {
      points.addAll([_turnX, _turnY]);
      widths.add(_weight);
      added = true;
    }
    final dx = _x - points[points.length - 2],
        dy = _y - points[points.length - 1];
    if (dx * dx + dy * dy >= _spacing * _spacing * pixel * pixel) {
      points.addAll([_x, _y]);
      widths.add(_weight);
      added = true;
    }
    if (added || b >= arm) {
      _turnX = _x;
      _turnY = _y;
    }
    return added;
  }

  /// Ends the stroke exactly where the pointer was lifted.
  void finish(double x, double y) {
    if (points.isEmpty) return;
    final dx = x - points[points.length - 2],
        dy = y - points[points.length - 1];
    if (dx * dx + dy * dy < 0.01) return;
    points.addAll([x, y]);
    widths.add(_weight);
  }
}

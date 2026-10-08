import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../data/library.dart';
import '../l10n/app_localizations.dart';
import 'mark.dart';

enum DrawTool {
  pen,
  fountain,
  brush,
  pencil,
  marker,
  eraser,
  line,
  arrow,
  rect,
  ellipse,
  text,

  /// Only offered over a book: stick a note on the page.
  sticky,

  /// Only offered over a book: attach a notebook page to the spot.
  page,
}

/// The tool, color and thickness in hand. Remembered between sessions.
class DrawSettings extends ChangeNotifier {
  DrawSettings(this._library) {
    _tool =
        DrawTool.values.asNameMap()[_library.setting('draw.tool')] ??
        DrawTool.pen;
    final color = int.tryParse(_library.setting('draw.color') ?? '');
    _color = color == null ? markColors[6] : Color(color);
    _width =
        double.tryParse(_library.setting('draw.width') ?? '') ?? markWidths[1];
  }

  final Library _library;
  late DrawTool _tool;
  late Color _color;
  late double _width;

  DrawTool get tool => _tool;
  set tool(DrawTool value) {
    if (value == _tool) return;
    _tool = value;
    _library.setSetting('draw.tool', value.name);
    notifyListeners();
  }

  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    _library.setSetting('draw.color', '${value.toARGB32()}');
    notifyListeners();
  }

  double get width => _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    _library.setSetting('draw.width', '$value');
    notifyListeners();
  }

  /// The kind of mark the current tool leaves, or null for tools that
  /// don't draw (eraser, sticky note, attached page).
  MarkTool? get markTool => switch (_tool) {
    DrawTool.pen => MarkTool.pen,
    DrawTool.fountain => MarkTool.fountain,
    DrawTool.brush => MarkTool.brush,
    DrawTool.pencil => MarkTool.pencil,
    DrawTool.marker => MarkTool.marker,
    DrawTool.line => MarkTool.line,
    DrawTool.arrow => MarkTool.arrow,
    DrawTool.rect => MarkTool.rect,
    DrawTool.ellipse => MarkTool.ellipse,
    DrawTool.text => MarkTool.text,
    _ => null,
  };

  bool get isShape =>
      _tool == DrawTool.line ||
      _tool == DrawTool.arrow ||
      _tool == DrawTool.rect ||
      _tool == DrawTool.ellipse;

  /// Whether the current tool's strokes vary in weight along their length
  /// even without a pressure-sensitive stylus.
  bool get isExpressive => _tool == DrawTool.brush;

  /// A new mark of the current tool through [points]. [widths] gives the
  /// weight at each point for strokes that vary.
  Mark? mark(List<double> points, {List<double>? widths, String text = ''}) {
    final tool = markTool;
    return tool == null
        ? null
        : Mark(
            tool: tool,
            color: _color,
            width: _width,
            points: points,
            widths: widths,
            text: text,
          );
  }
}

/// Floating tool picker in the manner of the one on an iPad: the writing
/// tools stand in a row and the chosen one rises; then shapes and text,
/// ink colors, thickness, and undo.
class DrawToolbar extends StatelessWidget {
  const DrawToolbar({
    super.key,
    required this.settings,
    required this.onUndo,
    this.onRedo,
    this.bookTools = false,
    this.onClose,
  });

  final DrawSettings settings;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  /// Whether to offer the sticky note and attached page tools.
  final bool bookTools;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = MacColors.of(context);

    Widget gap() => Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.outlineVariant,
    );

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final shapeNames = {
          DrawTool.line: (l.shapeLine, CupertinoIcons.minus),
          DrawTool.arrow: (l.shapeArrow, CupertinoIcons.arrow_up_right),
          DrawTool.rect: (l.shapeRect, CupertinoIcons.rectangle),
          DrawTool.ellipse: (l.shapeEllipse, CupertinoIcons.circle),
        };
        return Material(
          color: colors.group,
          elevation: 10,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          // The picker reads the same way in every language, like a
          // pencil case.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 54,
                child: Row(
                  children: [
                    for (final (tool, name) in [
                      (DrawTool.pen, l.toolPen),
                      (DrawTool.fountain, l.toolFountain),
                      (DrawTool.brush, l.toolBrush),
                      (DrawTool.pencil, l.toolPencil),
                      (DrawTool.marker, l.toolMarker),
                      (DrawTool.eraser, l.toolEraser),
                    ])
                      _PenButton(
                        tool: tool,
                        label: name,
                        color: settings.color,
                        selected: settings.tool == tool,
                        onTap: () => settings.tool = tool,
                      ),
                    gap(),
                    PopupMenuButton<DrawTool>(
                      tooltip: l.toolShapes,
                      onSelected: (tool) => settings.tool = tool,
                      itemBuilder: (context) => [
                        for (final entry in shapeNames.entries)
                          PopupMenuItem(
                            value: entry.key,
                            height: 32,
                            child: Row(
                              spacing: 10,
                              children: [
                                Icon(entry.value.$2, size: 16),
                                Text(entry.value.$1),
                              ],
                            ),
                          ),
                      ],
                      child: _ToolChip(
                        icon:
                            shapeNames[settings.tool]?.$2 ??
                            CupertinoIcons.square_on_circle,
                        selected: settings.isShape,
                      ),
                    ),
                    _ToolChip(
                      icon: CupertinoIcons.textformat,
                      tooltip: l.toolText,
                      selected: settings.tool == DrawTool.text,
                      onTap: () => settings.tool = DrawTool.text,
                    ),
                    if (bookTools) ...[
                      _ToolChip(
                        icon: CupertinoIcons.square_fill,
                        iconColor: const Color(0xFFF2C200),
                        tooltip: l.toolSticky,
                        selected: settings.tool == DrawTool.sticky,
                        onTap: () => settings.tool = DrawTool.sticky,
                      ),
                      _ToolChip(
                        icon: CupertinoIcons.doc_append,
                        tooltip: l.toolPage,
                        selected: settings.tool == DrawTool.page,
                        onTap: () => settings.tool = DrawTool.page,
                      ),
                    ],
                    gap(),
                    for (final color in markColors)
                      _ColorDot(
                        color: color,
                        selected: settings.color == color,
                        onTap: () => settings.color = color,
                      ),
                    gap(),
                    for (final width in markWidths)
                      Tooltip(
                        message: l.thickness,
                        child: InkWell(
                          onTap: () => settings.width = width,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: settings.width == width
                                  ? colors.selection
                                  : Colors.transparent,
                            ),
                            child: Container(
                              width: 4 + width * 2.6,
                              height: 4 + width * 2.6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    gap(),
                    MacIconButton(
                      icon: CupertinoIcons.arrow_uturn_left,
                      tooltip: l.undo,
                      onPressed: onUndo,
                    ),
                    if (onRedo != null)
                      MacIconButton(
                        icon: CupertinoIcons.arrow_uturn_right,
                        tooltip: l.redo,
                        onPressed: onRedo,
                      ),
                    if (onClose != null)
                      MacIconButton(
                        icon: CupertinoIcons.xmark,
                        tooltip: l.done,
                        onPressed: onClose,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.selected,
    this.iconColor,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color? iconColor;
  final String? tooltip;

  /// Null when a parent (a pop-up menu button) handles the press.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: selected ? MacColors.of(context).selection : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 19,
        color:
            iconColor ??
            (selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface),
      ),
    );
    if (onTap == null) return chip;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: chip,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.onSurface
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
        ),
      ),
    );
  }
}

/// A writing tool standing in the tray: it sits low until chosen, then
/// rises.
class _PenButton extends StatelessWidget {
  const _PenButton({
    required this.tool,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final DrawTool tool;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 29,
            height: 54,
            child: ClipRect(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                offset: Offset(0, selected ? 0.12 : 0.36),
                child: CustomPaint(painter: _PenGlyph(tool, color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PenGlyph extends CustomPainter {
  const _PenGlyph(this.tool, this.color);

  final DrawTool tool;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final left = w * 0.24, right = w * 0.76, mid = w / 2;
    final shoulder = h * 0.36;
    Paint fill(Color c) => Paint()..color = c;
    Path polygon(List<Offset> points) => Path()..addPolygon(points, true);

    final body = RRect.fromLTRBAndCorners(
      left,
      shoulder,
      right,
      h,
      topLeft: const Radius.circular(1.5),
      topRight: const Radius.circular(1.5),
    );
    switch (tool) {
      case DrawTool.pencil:
        canvas.drawRRect(body, fill(const Color(0xFFE9B949)));
        canvas.drawPath(
          polygon([
            Offset(left, shoulder),
            Offset(right, shoulder),
            Offset(mid, h * 0.06),
          ]),
          fill(const Color(0xFFE7C9A0)),
        );
        canvas.drawPath(
          polygon([
            Offset(mid - w * 0.09, h * 0.16),
            Offset(mid + w * 0.09, h * 0.16),
            Offset(mid, h * 0.06),
          ]),
          fill(color),
        );
      case DrawTool.fountain:
        canvas.drawRRect(body, fill(const Color(0xFF22324E)));
        // A metal nib with its slit.
        canvas.drawPath(
          polygon([
            Offset(left, shoulder),
            Offset(right, shoulder),
            Offset(mid + w * 0.07, h * 0.12),
            Offset(mid, h * 0.05),
            Offset(mid - w * 0.07, h * 0.12),
          ]),
          fill(const Color(0xFFD9C27A)),
        );
        canvas.drawLine(
          Offset(mid, h * 0.08),
          Offset(mid, h * 0.27),
          Paint()
            ..color = const Color(0xFF6B5A22)
            ..strokeWidth = 1,
        );
        canvas.drawCircle(Offset(mid, h * 0.28), 1.3, fill(color));
      case DrawTool.brush:
        canvas.drawRRect(body, fill(const Color(0xFF7A5230)));
        // Metal ferrule, then a tuft that comes to a point.
        canvas.drawRect(
          Rect.fromLTRB(left, shoulder - h * 0.06, right, shoulder + 1),
          fill(const Color(0xFFB9B9BE)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(left + w * 0.03, shoulder - h * 0.06)
            ..quadraticBezierTo(left - w * 0.04, h * 0.2, mid, h * 0.04)
            ..quadraticBezierTo(
              right + w * 0.04,
              h * 0.2,
              right - w * 0.03,
              shoulder - h * 0.06,
            )
            ..close(),
          fill(color),
        );
      case DrawTool.marker:
        canvas.drawRRect(body, fill(const Color(0xFF4A4A4E)));
        canvas.drawPath(
          polygon([
            Offset(left + w * 0.04, shoulder),
            Offset(right - w * 0.04, shoulder),
            Offset(right - w * 0.08, h * 0.1),
            Offset(left + w * 0.08, h * 0.2),
          ]),
          fill(color),
        );
      case DrawTool.eraser:
        canvas.drawRRect(body, fill(const Color(0xFFD8D8DD)));
        canvas.drawRRect(
          RRect.fromLTRBR(
            left,
            h * 0.12,
            right,
            shoulder + 1,
            const Radius.circular(3),
          ),
          fill(const Color(0xFFF4A0A8)),
        );
        return;
      default:
        canvas.drawRRect(body, fill(const Color(0xFF3A3A3C)));
        canvas.drawPath(
          polygon([
            Offset(left, shoulder),
            Offset(right, shoulder),
            Offset(mid, h * 0.06),
          ]),
          fill(const Color(0xFFB9B9BE)),
        );
        canvas.drawPath(
          polygon([
            Offset(mid - w * 0.07, h * 0.15),
            Offset(mid + w * 0.07, h * 0.15),
            Offset(mid, h * 0.06),
          ]),
          fill(color),
        );
    }
    // A band in the ink color, so the tray shows what each tool writes in.
    canvas.drawRect(
      Rect.fromLTRB(left, h * 0.44, right, h * 0.52),
      fill(color),
    );
  }

  @override
  bool shouldRepaint(_PenGlyph old) => old.tool != tool || old.color != color;
}

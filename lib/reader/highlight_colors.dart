import 'dart:ui';

import '../data/models.dart';

extension HighlightColorSwatch on HighlightColor {
  /// Solid color for swatches and list markers.
  Color get swatch => switch (this) {
    HighlightColor.yellow => const Color(0xFFFFD60A),
    HighlightColor.green => const Color(0xFF5FD068),
    HighlightColor.blue => const Color(0xFF5AB0FF),
    HighlightColor.pink => const Color(0xFFFF7EB6),
    HighlightColor.purple => const Color(0xFFC08CFF),
  };

  /// Darker shade of the same hue for pen strokes, readable on white.
  Color get ink => switch (this) {
    HighlightColor.yellow => const Color(0xFFD99A00),
    HighlightColor.green => const Color(0xFF1E9E4A),
    HighlightColor.blue => const Color(0xFF1F6FEB),
    HighlightColor.pink => const Color(0xFFE0408A),
    HighlightColor.purple => const Color(0xFF8A4FD8),
  };

  /// Translucent color laid over the page text, darkening it like a marker.
  Color get marker => swatch.withValues(alpha: 0.5);
}

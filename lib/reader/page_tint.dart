import 'dart:ui';

/// Paper presets the reader can recolor a PDF page to.
enum PagePaper { original, paper, sepia, green, gray, dark, black }

/// Recolors rendered pages on the GPU: white becomes the preset's paper
/// color and black its ink color. Dark presets flip lightness while keeping
/// hue, so a red chart line stays red instead of turning cyan. It can also
/// make text heavier, with or without a preset.
class PageTint {
  const PageTint({
    this.paper = PagePaper.original,
    this.strength = 1,
    this.contrast = 1,
    this.weight = 0,
  });

  final PagePaper paper;

  /// 0 leaves the page untouched, 1 applies the preset fully.
  final double strength;

  /// 1 keeps full ink contrast, lower values soften ink toward the paper.
  final double contrast;

  /// 0 leaves text as rendered; higher values darken the soft gray edge
  /// pixels of each letter so strokes read heavier.
  final double weight;

  static const minContrast = 0.4;

  /// Darkening factor reached at full [weight].
  static const _maxWeightGain = 0.7;

  /// Whether a paper preset is in effect.
  bool get recolors => paper != PagePaper.original && strength > 0;

  bool get isIdentity => !recolors && weight <= 0;

  bool get isDark => paper == PagePaper.dark || paper == PagePaper.black;

  /// Color a pure white page ends up with at full strength.
  Color get paperColor => switch (paper) {
    PagePaper.original => const Color(0xFFFFFFFF),
    PagePaper.paper => const Color(0xFFF6F1E4),
    PagePaper.sepia => const Color(0xFFF0E2C4),
    PagePaper.green => const Color(0xFFDCE8D6),
    PagePaper.gray => const Color(0xFFD9D9D6),
    PagePaper.dark => const Color(0xFF1C1F1E),
    PagePaper.black => const Color(0xFF000000),
  };

  /// Color pure black text ends up with at full strength and contrast.
  Color get inkColor => switch (paper) {
    PagePaper.original => const Color(0xFF000000),
    PagePaper.paper => const Color(0xFF2B2A26),
    PagePaper.sepia => const Color(0xFF3B2F1E),
    PagePaper.green => const Color(0xFF1F2A22),
    PagePaper.gray => const Color(0xFF1E1E1E),
    PagePaper.dark => const Color(0xFFD5D9D4),
    PagePaper.black => const Color(0xFFC8C8C8),
  };

  PageTint copyWith({
    PagePaper? paper,
    double? strength,
    double? contrast,
    double? weight,
  }) => PageTint(
    paper: paper ?? this.paper,
    strength: strength ?? this.strength,
    contrast: contrast ?? this.contrast,
    weight: weight ?? this.weight,
  );

  ColorFilter? get filter => isIdentity ? null : ColorFilter.matrix(matrix());

  /// 5x4 row-major color matrix in the layout [ColorFilter.matrix] expects
  /// (channels and offsets on a 0..255 scale).
  List<double> matrix() {
    const identity = <double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
    if (isIdentity) return identity;
    final recolor = recolors ? _recolorMatrix(identity) : identity;

    // Text weight runs first: v' = 255 - gain * (255 - v) keeps white and
    // pushes everything else darker. Folding it into the recolor matrix
    // keeps the whole effect a single GPU pass.
    final gain = 1 + weight.clamp(0.0, 1.0) * _maxWeightGain;
    final shift = 255 * (1 - gain);
    final out = List<double>.of(recolor);
    for (var row = 0; row < 3; row++) {
      final r = row * 5;
      out[r + 4] += (recolor[r] + recolor[r + 1] + recolor[r + 2]) * shift;
      for (var j = 0; j < 3; j++) {
        out[r + j] *= gain;
      }
    }
    return out;
  }

  List<double> _recolorMatrix(List<double> identity) {
    final c = contrast.clamp(minContrast, 1.0);
    final p = _rgb(paperColor);
    final i = _rgb(inkColor);
    final m = List<double>.filled(20, 0);
    m[18] = 1;

    for (var ch = 0; ch < 3; ch++) {
      // Value black maps to and value white maps to, after softening contrast.
      final ink = p[ch] + (i[ch] - p[ch]) * c;
      final row = ch * 5;
      if (isDark) {
        // t = v + 255 - 2Y flips lightness around the gray axis (invert
        // followed by a 180° hue rotation), then t is scaled into paper..ink.
        const luma = [0.2126, 0.7152, 0.0722];
        final k = (ink - p[ch]) / 255;
        for (var j = 0; j < 3; j++) {
          m[row + j] = k * ((j == ch ? 1 : 0) - 2 * luma[j]);
        }
        m[row + 4] = p[ch] + k * 255;
      } else {
        m[row + ch] = (p[ch] - ink) / 255;
        m[row + 4] = ink;
      }
    }

    final s = strength.clamp(0.0, 1.0);
    return [
      for (var n = 0; n < 20; n++) identity[n] + (m[n] - identity[n]) * s,
    ];
  }

  /// The color [color] turns into under this tint.
  Color apply(Color color) {
    final m = matrix();
    final rgb = _rgb(color);
    int channel(int row) =>
        (m[row * 5] * rgb[0] +
                m[row * 5 + 1] * rgb[1] +
                m[row * 5 + 2] * rgb[2] +
                m[row * 5 + 4])
            .round()
            .clamp(0, 255);
    return Color.fromARGB(255, channel(0), channel(1), channel(2));
  }

  static List<double> _rgb(Color c) => [c.r * 255, c.g * 255, c.b * 255];

  Map<String, Object> toJson() => {
    'paper': paper.name,
    'strength': strength,
    'contrast': contrast,
    'weight': weight,
  };

  factory PageTint.fromJson(Map<String, Object?> json) => PageTint(
    paper: PagePaper.values.asNameMap()[json['paper']] ?? PagePaper.original,
    strength: (json['strength'] as num?)?.toDouble() ?? 1,
    contrast: (json['contrast'] as num?)?.toDouble() ?? 1,
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is PageTint &&
      other.paper == paper &&
      other.strength == strength &&
      other.contrast == contrast &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(paper, strength, contrast, weight);
}

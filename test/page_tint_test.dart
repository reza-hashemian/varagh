import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/reader/page_tint.dart';

/// Applies a 5x4 color matrix to an opaque RGB color (0..255 channels).
List<double> apply(List<double> m, List<double> rgb) => [
  for (var row = 0; row < 3; row++)
    (m[row * 5] * rgb[0] +
            m[row * 5 + 1] * rgb[1] +
            m[row * 5 + 2] * rgb[2] +
            m[row * 5 + 3] * 255 +
            m[row * 5 + 4])
        .clamp(0, 255),
];

List<double> rgbOf(dynamic c) => [c.r * 255, c.g * 255, c.b * 255];

void expectRgb(List<double> actual, List<double> expected) {
  for (var i = 0; i < 3; i++) {
    expect(actual[i], closeTo(expected[i], 0.5));
  }
}

void main() {
  const white = [255.0, 255.0, 255.0];
  const black = [0.0, 0.0, 0.0];

  test('original paper leaves colors untouched', () {
    const tint = PageTint();
    expect(tint.filter, isNull);
    expectRgb(apply(tint.matrix(), [12, 200, 77]), [12, 200, 77]);
  });

  test('every preset maps white to paper and black to ink', () {
    for (final paper in PagePaper.values) {
      final tint = PageTint(paper: paper);
      final m = tint.matrix();
      expectRgb(apply(m, white), rgbOf(tint.paperColor));
      expectRgb(apply(m, black), rgbOf(tint.inkColor));
    }
  });

  test('zero strength is the identity', () {
    const tint = PageTint(paper: PagePaper.sepia, strength: 0);
    expect(tint.filter, isNull);
    expectRgb(apply(tint.matrix(), white), white);
  });

  test('half strength lands midway between white and paper', () {
    const tint = PageTint(paper: PagePaper.sepia, strength: 0.5);
    final paper = rgbOf(tint.paperColor);
    expectRgb(apply(tint.matrix(), white), [
      for (final c in paper) (255 + c) / 2,
    ]);
  });

  test('lower contrast moves ink toward paper and keeps paper', () {
    const full = PageTint(paper: PagePaper.paper);
    const soft = PageTint(paper: PagePaper.paper, contrast: 0.5);
    expectRgb(apply(soft.matrix(), white), rgbOf(soft.paperColor));
    expect(
      apply(soft.matrix(), black)[0],
      greaterThan(apply(full.matrix(), black)[0]),
    );
  });

  test('dark preset keeps the hue of a saturated color', () {
    const tint = PageTint(paper: PagePaper.dark);
    final red = apply(tint.matrix(), [255, 0, 0]);
    expect(red[0], greaterThan(red[1]));
    expect(red[0], greaterThan(red[2]));
  });

  test('apply matches what the filter does to a color', () {
    const tint = PageTint(paper: PagePaper.sepia);
    expect(tint.apply(const Color(0xFFFFFFFF)), tint.paperColor);
    expect(
      const PageTint().apply(const Color(0xFF123456)),
      const Color(0xFF123456),
    );
  });

  test('text weight darkens gray edges but keeps white and black', () {
    const tint = PageTint(weight: 1);
    expect(tint.filter, isNotNull);
    expectRgb(apply(tint.matrix(), white), white);
    expectRgb(apply(tint.matrix(), black), black);
    expect(apply(tint.matrix(), [128, 128, 128])[0], lessThan(60));
  });

  test('text weight keeps the paper color under a preset', () {
    const plain = PageTint(paper: PagePaper.sepia);
    const heavy = PageTint(paper: PagePaper.sepia, weight: 1);
    expectRgb(apply(heavy.matrix(), white), rgbOf(heavy.paperColor));
    expect(
      apply(heavy.matrix(), [128, 128, 128])[0],
      lessThan(apply(plain.matrix(), [128, 128, 128])[0]),
    );
    const dark = PageTint(paper: PagePaper.dark, weight: 1);
    expectRgb(apply(dark.matrix(), white), rgbOf(dark.paperColor));
    expect(
      apply(dark.matrix(), [128, 128, 128])[0],
      greaterThan(
        apply(const PageTint(paper: PagePaper.dark).matrix(), [
          128,
          128,
          128,
        ])[0],
      ),
    );
  });

  test('round-trips through JSON', () {
    const tint = PageTint(
      paper: PagePaper.green,
      strength: 0.7,
      contrast: 0.8,
      weight: 0.4,
    );
    expect(PageTint.fromJson(tint.toJson()), tint);
  });
}

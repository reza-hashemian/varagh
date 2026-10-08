import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// App-wide look. [paper] is a warm light theme, [black] is true black for
/// OLED screens.
enum AppLook { light, paper, dark, black }

/// Accent choices, mirroring the ones macOS offers.
enum AppAccent { blue, purple, pink, red, orange, green, graphite }

extension AppAccentColor on AppAccent {
  Color resolve(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      AppAccent.blue => Color(dark ? 0xFF0A84FF : 0xFF007AFF),
      AppAccent.purple => Color(dark ? 0xFFBF5AF2 : 0xFF953D96),
      AppAccent.pink => Color(dark ? 0xFFFF5FA2 : 0xFFD9408A),
      AppAccent.red => Color(dark ? 0xFFFF5A52 : 0xFFD9363E),
      AppAccent.orange => Color(dark ? 0xFFFF9F0A : 0xFFC96A0A),
      AppAccent.green => Color(dark ? 0xFF32D74B : 0xFF2E8B3D),
      AppAccent.graphite => Color(dark ? 0xFF98989D : 0xFF6E6E73),
    };
  }
}

/// Surfaces the Material color scheme has no slot for.
class MacColors extends ThemeExtension<MacColors> {
  const MacColors({
    required this.sidebar,
    required this.toolbar,
    required this.group,
    required this.selection,
    required this.control,
  });

  /// Source-list column beside the content.
  final Color sidebar;

  /// Bar across the top of a pane.
  final Color toolbar;

  /// Fill of a grouped settings box.
  final Color group;

  /// Fill behind the selected sidebar or list row.
  final Color selection;

  /// Fill of push buttons, pop-up buttons and search fields.
  final Color control;

  static MacColors of(BuildContext context) =>
      Theme.of(context).extension<MacColors>()!;

  @override
  MacColors copyWith() => this;

  @override
  MacColors lerp(MacColors? other, double t) => t < 0.5 ? this : other ?? this;
}

class _Palette {
  const _Palette({
    required this.brightness,
    required this.content,
    required this.window,
    required this.sidebar,
    required this.toolbar,
    required this.group,
    required this.control,
    required this.line,
    required this.ink,
    required this.inkSoft,
  });

  final Brightness brightness;
  final Color content, window, sidebar, toolbar, group, control;
  final Color line, ink, inkSoft;
}

const _palettes = <AppLook, _Palette>{
  AppLook.light: _Palette(
    brightness: Brightness.light,
    content: Color(0xFFFFFFFF),
    window: Color(0xFFECECEC),
    sidebar: Color(0xFFE9E9EA),
    toolbar: Color(0xFFF6F6F6),
    group: Color(0xFFF7F7F7),
    control: Color(0xFFFFFFFF),
    line: Color(0xFFD4D4D6),
    ink: Color(0xFF262626),
    inkSoft: Color(0xFF6E6E73),
  ),
  AppLook.paper: _Palette(
    brightness: Brightness.light,
    content: Color(0xFFF8F2E4),
    window: Color(0xFFEFE7D6),
    sidebar: Color(0xFFEAE1CD),
    toolbar: Color(0xFFF3ECDC),
    group: Color(0xFFF6EFDF),
    control: Color(0xFFFBF7EC),
    line: Color(0xFFD8CCB3),
    ink: Color(0xFF2B2A26),
    inkSoft: Color(0xFF6B6455),
  ),
  AppLook.dark: _Palette(
    brightness: Brightness.dark,
    content: Color(0xFF1E1E1E),
    window: Color(0xFF232323),
    sidebar: Color(0xFF2A2A2C),
    toolbar: Color(0xFF2B2B2D),
    group: Color(0xFF2C2C2E),
    control: Color(0xFF3A3A3C),
    line: Color(0xFF3F3F42),
    ink: Color(0xFFE4E4E7),
    inkSoft: Color(0xFF98989D),
  ),
  AppLook.black: _Palette(
    brightness: Brightness.dark,
    content: Color(0xFF000000),
    window: Color(0xFF050505),
    sidebar: Color(0xFF0C0C0D),
    toolbar: Color(0xFF0C0C0D),
    group: Color(0xFF131314),
    control: Color(0xFF1F1F21),
    line: Color(0xFF2A2A2C),
    ink: Color(0xFFCFCFD2),
    inkSoft: Color(0xFF8A8A8F),
  ),
};

const appFontFamily = 'Vazirmatn';

/// Preview colors for the appearance picker: (window, sidebar, ink).
(Color, Color, Color) lookPreview(AppLook look) {
  final p = _palettes[look]!;
  return (p.content, p.sidebar, p.ink);
}

class _NoTransitions extends PageTransitionsBuilder {
  const _NoTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

ThemeData buildTheme(AppLook look, AppAccent accentChoice) {
  final p = _palettes[look]!;
  final accent = accentChoice.resolve(p.brightness);
  final onAccent = accent.computeLuminance() > 0.45
      ? const Color(0xFF111111)
      : const Color(0xFFFFFFFF);
  final accentSoft = Color.alphaBlend(
    accent.withValues(alpha: 0.16),
    p.content,
  );
  final selection = p.ink.withValues(alpha: 0.09);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: p.brightness,
      ).copyWith(
        primary: accent,
        onPrimary: onAccent,
        primaryContainer: accentSoft,
        onPrimaryContainer: accent,
        secondary: accent,
        onSecondary: onAccent,
        secondaryContainer: accentSoft,
        onSecondaryContainer: accent,
        surface: p.content,
        onSurface: p.ink,
        onSurfaceVariant: p.inkSoft,
        surfaceContainerLowest: p.window,
        surfaceContainerLow: p.group,
        surfaceContainer: p.group,
        surfaceContainerHigh: p.toolbar,
        surfaceContainerHighest: p.sidebar,
        outline: p.inkSoft,
        outlineVariant: p.line,
        surfaceTint: Colors.transparent,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    scaffoldBackgroundColor: p.content,
    visualDensity: VisualDensity.compact,
    // macOS controls give no ink ripple, only a quiet pressed state.
    splashFactory: NoSplash.splashFactory,
    highlightColor: selection,
    hoverColor: p.ink.withValues(alpha: 0.05),
  );

  // 13pt body like macOS, with a little more leading for Persian text.
  final text = base.textTheme
      .copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: 22),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 14),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 11.5),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 13),
        labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 11.5),
      )
      .apply(heightFactor: 1.12, bodyColor: p.ink, displayColor: p.ink);

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(7),
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
  final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w500);

  return base.copyWith(
    textTheme: text,
    extensions: [
      MacColors(
        sidebar: p.sidebar,
        toolbar: p.toolbar,
        group: p.group,
        selection: selection,
        control: p.control,
      ),
    ],
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: p.brightness,
      primaryColor: accent,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 13,
          color: p.ink,
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.linux: _NoTransitions(),
        TargetPlatform.windows: _NoTransitions(),
        TargetPlatform.macOS: _NoTransitions(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    iconTheme: IconThemeData(color: p.ink, size: 18),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        padding: buttonPadding,
        minimumSize: const Size(0, 30),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: buttonShape,
        padding: buttonPadding,
        minimumSize: const Size(0, 30),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        padding: buttonPadding,
        minimumSize: const Size(0, 30),
        textStyle: buttonText,
        foregroundColor: p.ink,
        backgroundColor: p.control,
        side: BorderSide(color: p.line),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: const Size(32, 30),
        padding: EdgeInsets.zero,
        iconSize: 18,
        foregroundColor: p.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.control,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      hintStyle: text.bodyMedium?.copyWith(color: p.inkSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.group,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
      titleTextStyle: text.titleMedium,
      contentTextStyle: text.bodyMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.group,
      elevation: 8,
      menuPadding: const EdgeInsets.all(5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: p.line),
      ),
      textStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.group,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 700),
      decoration: BoxDecoration(
        color: p.group,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: p.line),
      ),
      textStyle: text.bodySmall,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
      backgroundColor: p.group,
      contentTextStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: p.line),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(7),
      radius: const Radius.circular(4),
      thumbColor: WidgetStatePropertyAll(p.ink.withValues(alpha: 0.3)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: p.ink.withValues(alpha: 0.12),
    ),
  );
}

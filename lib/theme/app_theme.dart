import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';

/// Material Design 3 主题。
///
/// Android 12+（API 31+）由 `dynamic_color` 提供系统壁纸取色；
/// 用户在「外观与显示」里选固定配色、或系统不支持动态取色时，
/// 回退到所选种子色生成的配色。
abstract final class AppTheme {
  /// 默认品牌种子色（`ThemeSeed.blue` 与动态取色的回退值）。
  static const Color seedColor = Color(0xFF3D5AFE);

  /// 各主题选项对应的种子色；[ThemeSeed.dynamic] 用默认品牌色兜底。
  static Color seedOf(ThemeSeed seed) => switch (seed) {
    ThemeSeed.dynamic => seedColor,
    ThemeSeed.blue => const Color(0xFF3D5AFE),
    ThemeSeed.green => const Color(0xFF2E7D32),
    ThemeSeed.orange => const Color(0xFFEF6C00),
    ThemeSeed.purple => const Color(0xFF7B1FA2),
    ThemeSeed.teal => const Color(0xFF00838F),
    ThemeSeed.red => const Color(0xFFC62828),
  };

  static ThemeData light({ColorScheme? dynamicScheme, Color? seed}) =>
      _build(Brightness.light, dynamicScheme, seed ?? seedColor);

  static ThemeData dark({ColorScheme? dynamicScheme, Color? seed}) =>
      _build(Brightness.dark, dynamicScheme, seed ?? seedColor);

  static ThemeData _build(
    Brightness brightness,
    ColorScheme? dynamicScheme,
    Color seed,
  ) {
    final ColorScheme scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return ThemeData(
      // Material 3 默认开启，显式声明以固定行为。
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
    );
  }
}

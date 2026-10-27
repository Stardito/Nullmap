import 'package:material_ui/material_ui.dart';

/// Material Design 3 主题。
///
/// Android 12+（API 31+）由 `dynamic_color` 提供系统壁纸取色；
/// iOS 与更低版本 Android 自动回退到 [seedColor] 生成的配色。
abstract final class AppTheme {
  /// 未启用动态取色时的品牌种子色。
  static const Color seedColor = Color(0xFF3D5AFE);

  static ThemeData light({ColorScheme? dynamicScheme}) =>
      _build(Brightness.light, dynamicScheme);

  static ThemeData dark({ColorScheme? dynamicScheme}) =>
      _build(Brightness.dark, dynamicScheme);

  static ThemeData _build(Brightness brightness, ColorScheme? dynamicScheme) {
    final ColorScheme scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

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

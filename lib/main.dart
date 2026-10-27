import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const NullMapApp());
}

/// 应用根节点。
///
/// [DynamicColorBuilder] 在 Android 12+ 返回系统壁纸配色，
/// 在 iOS 上返回 null，此时 [AppTheme] 使用种子色。
class NullMapApp extends StatelessWidget {
  const NullMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'NullMap',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: AppTheme.light(dynamicScheme: lightDynamic),
          darkTheme: AppTheme.dark(dynamicScheme: darkDynamic),
          home: const HomeScreen(),
        );
      },
    );
  }
}

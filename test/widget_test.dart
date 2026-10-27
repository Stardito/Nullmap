import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nullmap/screens/contacts_page.dart';
import 'package:nullmap/screens/home_screen.dart';
import 'package:nullmap/screens/map_page.dart';
import 'package:nullmap/screens/settings_page.dart';
import 'package:nullmap/theme/app_theme.dart';

Widget _app({ThemeMode mode = ThemeMode.light}) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: mode,
  home: const HomeScreen(),
);

void main() {
  testWidgets('底部导航默认停在地图页', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MapPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '地图'), findsOneWidget);
    expect(find.text('当前位置'), findsOneWidget);

    // IndexedStack 懒构建：未访问的页此时不在树里。
    expect(find.byType(ContactsPage), findsNothing);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('切换导航更新标题与页面', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(AppBar, '联系人'), findsOneWidget);
    expect(find.text('陈默'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
    expect(find.text('地图样式'), findsOneWidget);
  });

  testWidgets('联系人搜索过滤与空态', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(SearchBar).last, '周');
    await tester.pump();
    expect(find.text('周远'), findsOneWidget);
    expect(find.text('陈默'), findsNothing);

    await tester.enterText(find.byType(SearchBar).last, '不存在的人');
    await tester.pump();
    expect(find.text('没有匹配的联系人'), findsOneWidget);
  });

  testWidgets('深色模式使用 dark ColorScheme', (WidgetTester tester) async {
    await tester.pumpWidget(_app(mode: ThemeMode.dark));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ThemeData theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
  });
}

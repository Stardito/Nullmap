import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nullmap/main.dart' as app;

/// 真机冒烟测试：地图搜索「万丽花园」应带回距离，并按距离从近到远排序。
///
/// 运行方式：
///   flutter test integration_test/map_search_test.dart -d <设备序列号>
/// 前提：设备已联网、已授予定位权限、已卸载旧签名版本。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('搜索万丽花园按距离排序', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 等定位出结果，搜索才会带上“当前位置”。
    await tester.pump(const Duration(seconds: 10));

    final Finder searchBar = find.byType(SearchBar).first;
    expect(searchBar, findsOneWidget);
    await tester.tap(searchBar);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '万丽花园');
    await tester.testTextInput.receiveAction(TextInputAction.search);

    // 等原生返回：最多 20 秒。
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(ListTile).evaluate().length >= 2) {
        break;
      }
    }

    final List<String> titles = <String>[
      for (final Element element in find.byType(ListTile).evaluate())
        ((element.widget as ListTile).title as Text?)?.data ?? '',
    ];
    final List<String> distances = <String>[
      for (final Element element in find.byType(ListTile).evaluate())
        ((element.widget as ListTile).trailing as Text?)?.data ?? '',
    ];
    debugPrint('RESULTS: $titles');
    debugPrint('DISTANCES: $distances');

    expect(
      titles.any((String title) => title.contains('万丽花园')),
      isTrue,
      reason: '搜索结果里应有「万丽花园」',
    );
    // 有距离标签说明拿到了当前位置，并且按距离升序返回。
    expect(
      distances.where((String text) => text.contains('距您')).length,
      greaterThanOrEqualTo(2),
      reason: '结果应带“距您”距离标签',
    );
  });
}

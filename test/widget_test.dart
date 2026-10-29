import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nullmap/core/app_info.dart';
import 'package:nullmap/core/app_settings.dart';
import 'package:nullmap/core/localizations.dart';
import 'package:nullmap/data/contact.dart';
import 'package:nullmap/data/contact_store.dart';
import 'package:nullmap/screens/contacts_page.dart';
import 'package:nullmap/screens/home_screen.dart';
import 'package:nullmap/screens/map_page.dart';
import 'package:nullmap/screens/settings_page.dart';
import 'package:nullmap/services/backup.dart';
import 'package:nullmap/services/privacy.dart';
import 'package:nullmap/services/region_alerts.dart';
import 'package:nullmap/theme/app_theme.dart';
import 'package:nullmap/widgets/map_contact_sheet.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 跟随 [AppSettings] 重建的测试壳，行为与 main.dart 一致。
class _TestApp extends StatefulWidget {
  const _TestApp({this.mode, this.settings, this.store});

  final ThemeMode? mode;
  final AppSettings? settings;
  final ContactStore? store;

  @override
  State<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<_TestApp> {
  late final AppSettings _settings = widget.settings ?? AppSettings();
  late final ContactStore _store = widget.store!;

  @override
  Widget build(BuildContext context) {
    return ContactScope(
      store: _store,
      child: AppSettingsScope(
        settings: _settings,
        child: AnimatedBuilder(
          animation: _settings,
          builder: (BuildContext context, _) => MaterialApp(
            // 测试环境默认 en，读取稳定的中文文案。
            locale: _settings.locale ?? const Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            theme: AppTheme.light(seed: AppTheme.seedOf(_settings.themeSeed)),
            darkTheme: AppTheme.dark(
              seed: AppTheme.seedOf(_settings.themeSeed),
            ),
            themeMode: widget.mode ?? _settings.themeMode,
            home: const HomeScreen(),
          ),
        ),
      ),
    );
  }
}

void main() {
  late Directory tempDir;
  late ContactStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tempDir = await Directory.systemTemp.createTemp('nullmap_test');
    store = await ContactStore.open(directory: tempDir);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 上后台落盘可能仍占用文件，清理失败不影响测试结论。
    }
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(_TestApp(store: store, mode: mode));
    await tester.pumpAndSettle();
  }

  testWidgets('底部导航默认停在地图页', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MapPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '地图'), findsOneWidget);
    // 地图页只有底图与搜索框，不再有节点卡片。
    expect(find.text('搜索联系人'), findsOneWidget);
    expect(find.text('节点 A'), findsNothing);

    // IndexedStack 懒构建：未访问的页此时不在树里。
    expect(find.byType(ContactsPage), findsNothing);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('切换导航更新标题与页面', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '联系人'), findsOneWidget);
    expect(find.text('还没有联系人，点右下角新增'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
    expect(find.text('外观与显示'), findsOneWidget);
  });

  testWidgets('新增、搜索与删除联系人', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // 新增：填写姓名 + 手机号后保存。
    await tester.tap(find.byIcon(Icons.person_add_alt));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '新增联系人'), findsOneWidget);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '陈默');
    await tester.enterText(fields.at(4), '138 0000 1234');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(store.contacts, hasLength(1));
    expect(find.text('陈默'), findsOneWidget);

    // 搜索命中所在地 / 姓名。
    await tester.enterText(find.byType(SearchBar).last, '陈');
    await tester.pumpAndSettle();
    expect(find.text('陈默'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar).last, '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的联系人'), findsOneWidget);

    // 进入详情并删除。
    await tester.enterText(find.byType(SearchBar).last, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('陈默'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '陈默'), findsOneWidget);
    expect(find.text('138 0000 1234'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('删除联系人'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(store.contacts, isEmpty);
    expect(find.widgetWithText(AppBar, '联系人'), findsOneWidget);
    expect(find.text('还没有联系人，点右下角新增'), findsOneWidget);
  });

  testWidgets('联系人按国家/省/市/区筛选', (WidgetTester tester) async {
    store.add(
      const Contact(
        id: 'a',
        nickname: '阿一',
        country: '中国',
        province: '山东省',
        city: '淄博市',
        district: '临淄区',
      ),
    );
    store.add(
      const Contact(id: 'b', nickname: '阿二', country: '日本', address: '东京都千代田区'),
    );
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // 默认不限，两个联系人都显示。
    expect(find.text('阿一'), findsOneWidget);
    expect(find.text('阿二'), findsOneWidget);

    // 按国家筛选：中国只剩阿一。
    await tester.tap(find.text('国家: 全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中国').last);
    await tester.pumpAndSettle();
    expect(find.text('阿一'), findsOneWidget);
    expect(find.text('阿二'), findsNothing);
    expect(find.text('国家: 中国'), findsOneWidget);

    // 省 / 市 / 区逐级筛选仍然命中阿一。
    await tester.tap(find.text('省: 全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('山东省').last);
    await tester.pumpAndSettle();
    expect(find.text('阿一'), findsOneWidget);

    await tester.tap(find.text('市: 全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('淄博市').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('区/县: 全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('临淄区').last);
    await tester.pumpAndSettle();
    expect(find.text('阿一'), findsOneWidget);

    // 清掉国家筛选，“全部”恢复。
    await tester.tap(find.text('国家: 中国'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部').last);
    await tester.pumpAndSettle();
    expect(find.text('阿二'), findsOneWidget);
  });

  testWidgets('联系人详情可以跳到地图查看', (WidgetTester tester) async {
    store.add(
      const Contact(id: 'a', nickname: '阿一', latitude: 36.8, longitude: 118.3),
    );
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阿一'));
    await tester.pumpAndSettle();

    // 详情页出现“在地图上查看”（懒加载列表，先滚到底）；点击后回到根路由。
    await tester.scrollUntilVisible(
      find.text('在地图上查看'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('在地图上查看'), findsOneWidget);
    await tester.tap(find.text('在地图上查看'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactDetailPage), findsNothing);
  });

  testWidgets('深色模式使用 dark ColorScheme', (WidgetTester tester) async {
    await pumpApp(tester, mode: ThemeMode.dark);

    final ThemeData theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('设置页只有三个分组入口，详情在子页面', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('通用'), findsOneWidget);
    expect(find.text('外观与显示'), findsOneWidget);
    expect(find.text('关于项目'), findsOneWidget);
    // 入口卡片各带一行摘要。
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('标准'), findsOneWidget);
    expect(find.text(AppInfo.versionLabel), findsOneWidget);

    // 需求未包含的旧选项必须消失。
    expect(find.text('通知'), findsNothing);
    expect(find.text('自动同步'), findsNothing);
    expect(find.text('始终获取位置'), findsNothing);

    // 通用：只有显示语言。
    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '通用'), findsOneWidget);
    expect(find.text('显示语言'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // 外观与显示：地图 + 地图样式。
    await tester.tap(find.text('外观与显示'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '外观与显示'), findsOneWidget);
    expect(find.text('地图样式'), findsOneWidget);
    expect(find.text('卫星'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // 关于项目：名称、版本、开发者、仓库、许可。
    await tester.tap(find.text('关于项目'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '关于项目'), findsOneWidget);
    expect(find.text('零点地图-NullMap'), findsOneWidget);
    expect(find.text('Stardito/Nullmap'), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
  });

  testWidgets('切换显示语言后界面即时切换', (WidgetTester tester) async {
    final AppSettings settings = AppSettings();
    await tester.pumpWidget(_TestApp(store: store, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(settings.locale, const Locale('en'));
    expect(find.widgetWithText(AppBar, 'General'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Appearance & display'), findsOneWidget);
  });

  testWidgets('地图样式可切换并写入设置', (WidgetTester tester) async {
    final AppSettings settings = AppSettings();
    await tester.pumpWidget(_TestApp(store: store, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观与显示'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('卫星'));
    await tester.pumpAndSettle();
    expect(settings.mapStyle, MapStyle.satellite);

    await tester.tap(find.text('地形'));
    await tester.pumpAndSettle();
    expect(settings.mapStyle, MapStyle.terrain);

    await tester.tap(find.text('标准'));
    await tester.pumpAndSettle();
    expect(settings.mapStyle, MapStyle.standard);
  });

  testWidgets('地图标记面板：多个先列表，单个直接概览', (WidgetTester tester) async {
    store.add(
      const Contact(
        id: 'a',
        nickname: '阿一',
        phone: '13800000001',
        province: '山东省',
        city: '淄博市',
      ),
    );
    store.add(const Contact(id: 'b', nickname: '阿二'));

    Widget sheet(List<String> ids) => ContactScope(
      store: store,
      child: AppSettingsScope(
        settings: AppSettings(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(body: MapContactSheet(contactIds: ids)),
        ),
      ),
    );

    await tester.pumpWidget(sheet(<String>['a', 'b']));
    await tester.pumpAndSettle();
    expect(find.text('选择联系人'), findsOneWidget);
    expect(find.text('阿一'), findsOneWidget);
    expect(find.text('阿二'), findsOneWidget);

    await tester.tap(find.text('阿一'));
    await tester.pumpAndSettle();
    expect(find.text('查看联系人详情'), findsOneWidget);
    expect(find.text('13800000001'), findsOneWidget);
    expect(find.text('山东省淄博市'), findsOneWidget);

    await tester.tap(find.text('查看联系人详情'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactDetailPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '阿一'), findsOneWidget);
  });

  testWidgets('地图标记面板：单个联系人直接显示概览', (WidgetTester tester) async {
    store.add(const Contact(id: 'c', nickname: '阿三', phone: '13900000002'));
    await tester.pumpWidget(
      ContactScope(
        store: store,
        child: AppSettingsScope(
          settings: AppSettings(),
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: const Scaffold(
              body: MapContactSheet(contactIds: <String>['c']),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('选择联系人'), findsNothing);
    expect(find.text('查看联系人详情'), findsOneWidget);
    expect(find.text('13900000002'), findsOneWidget);
  });

  testWidgets('主题颜色与明暗模式可切换并写入设置', (WidgetTester tester) async {
    final AppSettings settings = AppSettings();
    await tester.pumpWidget(_TestApp(store: store, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观与显示'));
    await tester.pumpAndSettle();

    // 默认：跟随系统 + 跟随壁纸。
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.themeSeed, ThemeSeed.dynamic);
    expect(find.text('明暗模式'), findsOneWidget);
    expect(find.text('主题颜色'), findsOneWidget);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('主题颜色'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byTooltip('绿色'));
    await tester.pumpAndSettle();
    expect(settings.themeSeed, ThemeSeed.green);

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.light);
  });

  testWidgets('所在地区提醒可开关并选择判断粒度', (WidgetTester tester) async {
    final AppSettings settings = AppSettings();
    await tester.pumpWidget(_TestApp(store: store, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();

    // 默认开启，粒度为市。
    expect(settings.regionAlertsEnabled, isTrue);
    expect(settings.regionGranularity, RegionGranularity.city);
    expect(find.text('所在地区提醒'), findsOneWidget);
    expect(find.text('判断粒度'), findsOneWidget);

    await tester.tap(find.text('区'));
    await tester.pumpAndSettle();
    expect(settings.regionGranularity, RegionGranularity.district);

    // 关闭后粒度选择收起。
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(settings.regionAlertsEnabled, isFalse);
    expect(find.text('判断粒度'), findsNothing);
  });

  testWidgets('通知点击后联系人页套用地区筛选', (WidgetTester tester) async {
    store.add(
      const Contact(
        id: 'a',
        nickname: '阿一',
        country: '中国',
        province: '山东省',
        city: '淄博市',
        district: '临淄区',
      ),
    );
    store.add(const Contact(id: 'b', nickname: '阿二', country: '日本'));
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // 通知带来的筛选：省 + 市。
    regionSelectionRequest.value = const RegionSelection(
      province: '山东省',
      city: '淄博市',
    );
    await tester.pumpAndSettle();

    expect(find.text('省: 山东省'), findsOneWidget);
    expect(find.text('市: 淄博市'), findsOneWidget);
    expect(find.text('阿一'), findsOneWidget);
    expect(find.text('阿二'), findsNothing);

    // 重置，避免影响后续用例。
    regionSelectionRequest.value = null;
  });

  testWidgets('开启隐私锁后联系人打码，解锁后显示明文', (WidgetTester tester) async {
    store.add(
      const Contact(
        id: 'a',
        name: '张三',
        nickname: '阿一',
        qq: '123456789',
        phone: '13800000001',
        province: '山东省',
        city: '淄博市',
        district: '临淄区',
        address: '人民路 1 号',
      ),
    );
    final AppSettings settings = AppSettings();
    await settings.setPrivacyLock(true);
    // 屏幕锁在测试里直接算通过。
    DeviceAuth.override = () async => true;
    addTearDown(() => DeviceAuth.override = null);

    await tester.pumpWidget(_TestApp(store: store, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // 锁定：标题仍是昵称，手机号与地址打码。
    expect(find.text('阿一'), findsOneWidget);
    expect(find.textContaining('138••••0001'), findsOneWidget);
    expect(find.textContaining('13800000001'), findsNothing);
    expect(find.textContaining('人民路'), findsNothing);

    // 解锁后恢复明文，并出现上锁图标。
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('13800000001'), findsOneWidget);
    expect(find.textContaining('人民路'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('联系人标签在详情与地图筛选里可见', (WidgetTester tester) async {
    store.add(
      const Contact(id: 'a', nickname: '阿一', tags: <String>['家人', '常联系']),
    );
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阿一'));
    await tester.pumpAndSettle();

    // 详情页是懒加载 ListView，先把标签卡片滚进视野。
    await tester.scrollUntilVisible(
      find.text('标签'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('标签'), findsOneWidget);
    expect(find.widgetWithText(Chip, '家人'), findsOneWidget);
    expect(find.widgetWithText(Chip, '常联系'), findsOneWidget);

    // 回到地图：出现标签筛选，选「家人」后仍是同一个联系人。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();
    expect(find.text('标签: 全部'), findsOneWidget);
    await tester.tap(find.text('标签: 全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('家人').last);
    await tester.pumpAndSettle();
    expect(find.text('标签: 家人'), findsOneWidget);
  });

  testWidgets('备份导出与导入可往返联系人与标签', (WidgetTester tester) async {
    store.add(
      const Contact(
        id: 'a',
        nickname: '阿一',
        phone: '13800000001',
        tags: <String>['家人'],
      ),
    );
    final AppSettings settings = AppSettings();
    await settings.setPrivacyLock(true);

    String? saved;
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(BackupService.channel, (
      MethodCall call,
    ) async {
      switch (call.method) {
        case 'exportBackup':
          saved =
              (call.arguments as Map<Object?, Object?>)['content'] as String;
          return 'Downloads/nullmap.json';
        case 'importBackup':
          return saved;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(BackupService.channel, null),
    );

    final BackupResult exported = await BackupService.export(
      store: store,
      settings: settings,
    );
    expect(exported.ok, isTrue);
    expect(exported.count, 1);
    expect(saved, contains('家人'));
    expect(saved, contains('privacyLock'));

    store.replaceAll(const <Contact>[]);
    expect(store.contacts, isEmpty);

    final BackupResult restored = await BackupService.restore(
      store: store,
      settings: settings,
    );
    expect(restored.ok, isTrue);
    expect(restored.count, 1);
    expect(store.contacts.single.nickname, '阿一');
    expect(store.contacts.single.tags, <String>['家人']);
  });
}

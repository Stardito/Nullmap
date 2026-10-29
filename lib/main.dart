import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:material_ui/material_ui.dart';

import 'core/app_info.dart';
import 'core/app_settings.dart';
import 'core/localizations.dart';
import 'data/contact_store.dart';
import 'screens/home_screen.dart';
import 'services/region_alerts.dart';
import 'theme/app_theme.dart';

/// 全局 Navigator：通知点击时先把页面栈清回根节点。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 只允许竖屏：旋转设备时界面不翻转。
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  debugPrint('NullMap boot: ensureInitialized done');
  ContactStore? store;
  try {
    store = await ContactStore.open();
    debugPrint('NullMap boot: store opened (${store.contacts.length} contacts)');
  } on Exception catch (error) {
    // 文档目录不可用时退回临时目录，保证界面可用。
    debugPrint('NullMap boot: open failed ($error), falling back');
    store = await ContactStore.openFallback();
  }
  debugPrint('NullMap boot: runApp');
  runApp(NullMapApp(contactStore: store));
}

/// 应用根节点。
///
/// [DynamicColorBuilder] 在 Android 12+ 返回系统壁纸配色，
/// 在 iOS 上返回 null，此时 [AppTheme] 使用种子色。
/// 显示语言与地图样式由 [AppSettings] 统一管理。
class NullMapApp extends StatefulWidget {
  const NullMapApp({super.key, required this.contactStore});

  final ContactStore contactStore;

  @override
  State<NullMapApp> createState() => _NullMapAppState();
}

class _NullMapAppState extends State<NullMapApp> with WidgetsBindingObserver {
  final AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RegionAlerts.onOpen = _openRegionFromNotification;
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RegionAlerts.onOpen = null;
    _settings.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时再判断一次地区：用户可能已经开车到了另一个城市。
    if (state == AppLifecycleState.resumed) {
      _checkRegion();
    }
  }

  Future<void> _boot() async {
    await _settings.load();
    await RegionAlerts.initialize();
    // 通知权限只申请一次（Android 13+）：拒绝后不再每次启动弹窗，
    // 用户可以在系统设置里手动打开。否则后面发通知会被静默丢弃。
    if (!_settings.notificationsAsked) {
      await _settings.setNotificationsAsked();
      await RegionAlerts.requestPermission();
    }
    await _checkRegion();
  }

  Future<void> _checkRegion() async {
    await RegionAlerts.check(
      settings: _settings,
      contacts: widget.contactStore.contacts,
    );
  }

  void _openRegionFromNotification(RegionSelection selection) {
    appNavigatorKey.currentState?.popUntil(
      (Route<dynamic> route) => route.isFirst,
    );
    final HomeScreenState? home = homeScreenKey.currentState;
    if (home == null) {
      pendingRegionSelection = selection;
      return;
    }
    home.showRegionContacts(selection);
  }

  @override
  Widget build(BuildContext context) {
    return ContactScope(
      store: widget.contactStore,
      child: AppSettingsScope(
        settings: _settings,
        child: AnimatedBuilder(
          animation: _settings,
          builder: (BuildContext context, _) {
            return DynamicColorBuilder(
              builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
                // 只有「跟随壁纸」时采用系统动态配色，其余用固定种子色。
                final bool useDynamic =
                    _settings.themeSeed == ThemeSeed.dynamic;
                final Color seed = AppTheme.seedOf(_settings.themeSeed);
                return MaterialApp(
                  navigatorKey: appNavigatorKey,
                  onGenerateTitle: (_) => AppInfo.appNameFull,
                  debugShowCheckedModeBanner: false,
                  locale: _settings.locale,
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: appSupportedLocales,
                  themeMode: _settings.themeMode,
                  theme: AppTheme.light(
                    dynamicScheme: useDynamic ? lightDynamic : null,
                    seed: seed,
                  ),
                  darkTheme: AppTheme.dark(
                    dynamicScheme: useDynamic ? darkDynamic : null,
                    seed: seed,
                  ),
                  home: HomeScreen(key: homeScreenKey),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 地图底图样式。
enum MapStyle {
  /// 标准矢量底图。
  standard,

  /// 卫星影像。
  satellite,

  /// 地形。
  terrain,
}

/// 主题配色：跟随系统壁纸取色，或固定一个种子色。
enum ThemeSeed {
  /// Android 12+ 用壁纸取色；系统不支持时回退到 [blue]。
  dynamic,
  blue,
  green,
  orange,
  purple,
  teal,
  red,
}

/// 「所在地区变了」提醒的粒度。
enum RegionGranularity {
  province,
  city,
  district,
}

/// 应用级设置：显示语言、地图样式、主题配色、明暗模式与地区提醒。
///
/// 通过 [AppSettingsScope] 下发；改动会立即通知界面并写入本地存储。
class AppSettings extends ChangeNotifier {
  AppSettings({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _languageKey = 'display_language';
  static const String _mapStyleKey = 'map_style';
  static const String _themeSeedKey = 'theme_seed';
  static const String _themeModeKey = 'theme_mode';
  static const String _regionAlertsKey = 'region_alerts_enabled';
  static const String _regionGranularityKey = 'region_alert_granularity';
  static const String _regionAlertLastKey = 'region_alert_last';
  static const String _notificationsAskedKey = 'notifications_asked';

  final SharedPreferencesAsync _preferences;

  Locale? _locale;
  MapStyle _mapStyle = MapStyle.standard;
  ThemeSeed _themeSeed = ThemeSeed.dynamic;
  ThemeMode _themeMode = ThemeMode.system;
  bool _regionAlertsEnabled = true;
  RegionGranularity _regionGranularity = RegionGranularity.city;
  String _regionAlertLast = '';

  /// 是否已经申请过一次通知权限：只问一次，避免每次启动都弹窗。
  bool _notificationsAsked = false;

  /// `null` 表示跟随系统语言。
  Locale? get locale => _locale;

  MapStyle get mapStyle => _mapStyle;

  ThemeSeed get themeSeed => _themeSeed;

  ThemeMode get themeMode => _themeMode;

  /// 所在地区变化时是否发通知（默认开启）。
  bool get regionAlertsEnabled => _regionAlertsEnabled;

  /// 以哪一级行政区判断「地区变了」。
  RegionGranularity get regionGranularity => _regionGranularity;

  /// 上次记录的地区名，用来判断是否真的换了地方。
  String get regionAlertLast => _regionAlertLast;

  /// 通知权限是否已经申请过（只申请一次）。
  bool get notificationsAsked => _notificationsAsked;

  /// 读取已保存的设置；读取失败时保留默认值。
  Future<void> load() async {
    try {
      final String? language = await _preferences.getString(_languageKey);
      final String? style = await _preferences.getString(_mapStyleKey);
      final String? seed = await _preferences.getString(_themeSeedKey);
      final String? mode = await _preferences.getString(_themeModeKey);
      final bool? alerts = await _preferences.getBool(_regionAlertsKey);
      final String? granularity = await _preferences.getString(
        _regionGranularityKey,
      );
      final String? lastRegion = await _preferences.getString(
        _regionAlertLastKey,
      );
      final bool? notificationsAsked = await _preferences.getBool(
        _notificationsAskedKey,
      );
      _locale = switch (language) {
        null || '' => null,
        final String code => Locale(code),
      };
      _mapStyle = MapStyle.values.firstWhere(
        (MapStyle value) => value.name == style,
        orElse: () => MapStyle.standard,
      );
      _themeSeed = ThemeSeed.values.firstWhere(
        (ThemeSeed value) => value.name == seed,
        orElse: () => ThemeSeed.dynamic,
      );
      _themeMode = ThemeMode.values.firstWhere(
        (ThemeMode value) => value.name == mode,
        orElse: () => ThemeMode.system,
      );
      _regionAlertsEnabled = alerts ?? true;
      _regionGranularity = RegionGranularity.values.firstWhere(
        (RegionGranularity value) => value.name == granularity,
        orElse: () => RegionGranularity.city,
      );
      _regionAlertLast = lastRegion ?? '';
      _notificationsAsked = notificationsAsked ?? false;
      notifyListeners();
    } on Exception {
      // 读取失败不阻塞启动，继续使用默认值。
    }
  }

  /// 设置显示语言；`null` 表示跟随系统。
  Future<void> setLocale(Locale? locale) async {
    if (locale?.languageCode == _locale?.languageCode) {
      return;
    }
    _locale = locale;
    notifyListeners();
    await _preferences.setString(_languageKey, locale?.languageCode ?? '');
  }

  /// 设置地图样式。
  Future<void> setMapStyle(MapStyle style) async {
    if (style == _mapStyle) {
      return;
    }
    _mapStyle = style;
    notifyListeners();
    await _preferences.setString(_mapStyleKey, style.name);
  }

  /// 设置主题配色。
  Future<void> setThemeSeed(ThemeSeed seed) async {
    if (seed == _themeSeed) {
      return;
    }
    _themeSeed = seed;
    notifyListeners();
    await _preferences.setString(_themeSeedKey, seed.name);
  }

  /// 开关「所在地区变了」提醒。
  Future<void> setRegionAlertsEnabled(bool enabled) async {
    if (enabled == _regionAlertsEnabled) {
      return;
    }
    _regionAlertsEnabled = enabled;
    notifyListeners();
    await _preferences.setBool(_regionAlertsKey, enabled);
  }

  /// 设置提醒粒度（省 / 市 / 区）。
  Future<void> setRegionGranularity(RegionGranularity granularity) async {
    if (granularity == _regionGranularity) {
      return;
    }
    _regionGranularity = granularity;
    notifyListeners();
    await _preferences.setString(_regionGranularityKey, granularity.name);
  }

  /// 记录上一次所在地区（不触发界面重建）。
  Future<void> setRegionAlertLast(String region) async {
    if (region == _regionAlertLast) {
      return;
    }
    _regionAlertLast = region;
    await _preferences.setString(_regionAlertLastKey, region);
  }

  /// 标记通知权限已经申请过，避免每次启动重复弹窗。
  Future<void> setNotificationsAsked() async {
    if (_notificationsAsked) {
      return;
    }
    _notificationsAsked = true;
    await _preferences.setBool(_notificationsAskedKey, true);
  }

  /// 设置明暗模式（跟随系统 / 浅色 / 深色）。
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await _preferences.setString(_themeModeKey, mode.name);
  }
}

/// 把 [AppSettings] 下发给子树。
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final AppSettingsScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope 未在祖先节点中找到');
    return scope!.notifier!;
  }
}

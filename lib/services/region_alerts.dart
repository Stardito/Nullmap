import 'dart:io' show Platform;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/app_settings.dart';
import '../core/localizations.dart';
import '../data/contact.dart';
import '../l10n/app_localizations.dart';
import 'amap_service.dart';

/// 通知点击后要应用的地区筛选。
class RegionSelection {
  const RegionSelection({this.province = '', this.city = ''});

  final String province;
  final String city;
}

/// 通知点击请求：联系人页监听它来套用筛选。
final ValueNotifier<RegionSelection?> regionSelectionRequest =
    ValueNotifier<RegionSelection?>(null);

/// 通知点击时界面可能还没建好，先存这里，由 HomeScreen 建好后消费。
RegionSelection? pendingRegionSelection;

/// 「所在地区变了」提醒：判断当前定位的省/市/区是否变化，
/// 变化时发一条本地通知，点击后跳到联系人页并套用筛选。
class RegionAlerts {
  const RegionAlerts._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'region_alerts';
  static const String _channelName = '所在地区提醒';
  static const String _channelDescription = '当定位到的省/市/区变化时提醒附近有多少联系人';
  static const int _notificationId = 4201;

  static bool _initialized = false;

  /// 通知被点击时回调（由 main.dart 注入导航逻辑）。
  static void Function(RegionSelection selection)? onOpen;

  static Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) {
      return;
    }
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
    );
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _open(response.payload);
        },
      );
      _initialized = true;
    } on Object {
      // 初始化失败只影响通知，不影响主流程。
    }
  }

  /// 申请通知权限（Android 13+ 需要）。返回是否已授权。
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }
    await initialize();
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } on Object {
      return false;
    }
  }

  /// 检查当前地区是否变化；变化且有联系人时发通知。
  ///
  /// 第一次运行只记录基线不发通知，避免刚装好就弹一条。
  static Future<void> check({
    required AppSettings settings,
    required List<Contact> contacts,
  }) async {
    if (!settings.regionAlertsEnabled || !Platform.isAndroid) {
      return;
    }
    final Map<String, String>? region = await AmapService.currentAddress();
    if (region == null) {
      return;
    }
    final String name = _valueFor(region, settings.regionGranularity);
    if (name.isEmpty) {
      return;
    }
    final String last = settings.regionAlertLast;
    if (last == name) {
      return;
    }
    await settings.setRegionAlertLast(name);
    if (last.isEmpty) {
      return;
    }

    final List<Contact> matches = contacts
        .where((Contact contact) => _inRegion(contact, settings.regionGranularity, name))
        .toList();
    if (matches.isEmpty) {
      return;
    }
    await requestPermission();
    await _show(name, matches.length, region, settings);
  }

  static String _valueFor(
    Map<String, String> region,
    RegionGranularity granularity,
  ) {
    final String raw = switch (granularity) {
      RegionGranularity.province => region['province'] ?? '',
      RegionGranularity.city => region['city'] ?? '',
      RegionGranularity.district => region['district'] ?? '',
    };
    return raw.trim();
  }

  static bool _inRegion(
    Contact contact,
    RegionGranularity granularity,
    String name,
  ) {
    final String field = switch (granularity) {
      RegionGranularity.province => contact.province,
      RegionGranularity.city => contact.city,
      RegionGranularity.district => contact.district,
    };
    return field.trim() == name;
  }

  static Future<void> _show(
    String regionName,
    int count,
    Map<String, String> region,
    AppSettings settings,
  ) async {
    final AppLocalizations l10n = _localizations(settings);
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(l10n.regionAlertBody(regionName)),
    );
    try {
      await _plugin.show(
        id: _notificationId,
        title: l10n.regionAlertTitle(count, regionName),
        body: l10n.regionAlertBody(regionName),
        notificationDetails: NotificationDetails(android: android),
        payload: '${region['province'] ?? ''}|${region['city'] ?? ''}',
      );
    } on Object {
      // 通知失败不影响记录，下次进入还会再判断。
    }
  }

  static AppLocalizations _localizations(AppSettings settings) {
    final Locale? locale = settings.locale;
    if (locale != null) {
      return lookupAppLocalizations(locale);
    }
    final Locale system = PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(
      appSupportedLocales.contains(system)
          ? system
          : const Locale('en'),
    );
  }

  static void _open(String? payload) {
    final String raw = payload ?? '';
    final List<String> parts = raw.split('|');
    final RegionSelection selection = RegionSelection(
      province: parts.isNotEmpty ? parts[0] : '',
      city: parts.length > 1 ? parts[1] : '',
    );
    final void Function(RegionSelection selection)? handler = onOpen;
    if (handler == null) {
      pendingRegionSelection = selection;
      return;
    }
    handler(selection);
  }
}

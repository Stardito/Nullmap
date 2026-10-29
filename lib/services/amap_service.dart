import 'dart:io' show Platform;

import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;

/// 高德返回的一个地点候选。
class AmapPlace {
  const AmapPlace({
    required this.title,
    required this.snippet,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
  });

  final String title;
  final String snippet;
  final double latitude;
  final double longitude;

  /// 与当前位置的距离（米）；未定位时为空。
  final int? distanceMeters;
}

/// 高德返回的一级行政区划候选。
class AmapDistrict {
  const AmapDistrict({
    required this.name,
    required this.adcode,
    required this.level,
    this.latitude = 0,
    this.longitude = 0,
  });

  final String name;
  final String adcode;
  final String level;

  /// 行政区自身中心点；高德未返回时是 0（见 [hasCenter]）。
  final double latitude;
  final double longitude;

  /// 中心点是否可用。中国的经纬度不会同时为 0，因此 0/0 视为缺失。
  bool get hasCenter => latitude != 0 || longitude != 0;
}

/// `io.stardito.nullmap/amap` 通道的 Dart 封装。
///
/// 非 Android 平台直接返回空结果 / 不支持，调用方负责提示。
class AmapService {
  const AmapService._();

  static const MethodChannel channel = MethodChannel(
    'io.stardito.nullmap/amap',
  );

  static bool get isSupported => Platform.isAndroid;

  /// 地点搜索：原生按“附近优先”排序后返回。
  static Future<List<AmapPlace>> search(String keyword) async {
    if (!isSupported || keyword.trim().isEmpty) {
      return <AmapPlace>[];
    }
    try {
      final List<Object?>? raw = await channel.invokeMethod<List<Object?>>(
        'search',
        <String, Object>{'keyword': keyword.trim()},
      );
      return _places(raw);
    } on MissingPluginException {
      return <AmapPlace>[];
    } on PlatformException {
      return <AmapPlace>[];
    }
  }

  /// 地址输入提示，[city] 用于限制候选城市（空串表示全国）。
  static Future<List<AmapPlace>> inputTips(
    String keyword, {
    String city = '',
  }) async {
    if (!isSupported || keyword.trim().isEmpty) {
      return <AmapPlace>[];
    }
    try {
      final List<Object?>? raw = await channel.invokeMethod<List<Object?>>(
        'inputTips',
        <String, Object>{'keyword': keyword.trim(), 'city': city},
      );
      return _places(raw);
    } on MissingPluginException {
      return <AmapPlace>[];
    } on PlatformException {
      return <AmapPlace>[];
    }
  }

  /// 行政区划候选：`keyword` 为「中国」返回省，为省名返回市，为市名返回区县。
  ///
  /// [level] 可指定行政区级别（`country` / `province` / `city` / `district`），
  /// 留空时由高德按关键词自行判断。
  static Future<List<AmapDistrict>> districts(
    String keyword, {
    String level = '',
  }) async {
    if (!isSupported || keyword.trim().isEmpty) {
      return <AmapDistrict>[];
    }
    try {
      final List<Object?>? raw = await channel.invokeMethod<List<Object?>>(
        'districts',
        <String, Object>{'keyword': keyword.trim(), 'level': level},
      );
      return <AmapDistrict>[
        for (final Object? item in raw ?? <Object?>[])
          if (item is Map) _districtFromMap(item),
      ];
    } on MissingPluginException {
      return <AmapDistrict>[];
    } on PlatformException {
      return <AmapDistrict>[];
    }
  }

  /// 按名称查行政区自身的中心点，用于旧数据补全坐标。
  ///
  /// 与 [districts] 不同，这里返回的是该行政区自身的中心，而不是下辖区域；
  /// 查不到或平台不支持时返回 null。
  static Future<({double latitude, double longitude})?> districtCenter(
    String keyword, {
    String level = '',
  }) async {
    if (!isSupported || keyword.trim().isEmpty) {
      return null;
    }
    try {
      final Map<Object?, Object?>? raw = await channel
          .invokeMethod<Map<Object?, Object?>>(
            'districtCenter',
            <String, Object>{'keyword': keyword.trim(), 'level': level},
          );
      if (raw == null) {
        return null;
      }
      double readDouble(Object? value) => switch (value) {
        final num number => number.toDouble(),
        final String text => double.tryParse(text) ?? 0,
        _ => 0,
      };
      final double latitude = readDouble(raw['lat']);
      final double longitude = readDouble(raw['lng']);
      if (latitude == 0 && longitude == 0) {
        return null;
      }
      return (latitude: latitude, longitude: longitude);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 当前定位对应的省/市/区；定位不可用或未授权时返回 null。
  static Future<Map<String, String>?> currentAddress() async {
    if (!isSupported) {
      return null;
    }
    try {
      final Map<Object?, Object?>? raw = await channel
          .invokeMethod<Map<Object?, Object?>>('currentAddress');
      if (raw == null) {
        return null;
      }
      final String province = '${raw['province'] ?? ''}'.trim();
      final String city = '${raw['city'] ?? ''}'.trim();
      final String district = '${raw['district'] ?? ''}'.trim();
      if (province.isEmpty && city.isEmpty && district.isEmpty) {
        return null;
      }
      return <String, String>{
        'province': province,
        'city': city,
        'district': district,
      };
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 地址 → 省/市/区与坐标；解析不出来返回 null。
  static Future<
    ({
      String province,
      String city,
      String district,
      double latitude,
      double longitude,
    })?
  >
  geocodeDetail(String address, {String city = ''}) async {
    final String text = address.trim();
    if (text.isEmpty || !isSupported) {
      return null;
    }
    try {
      final Map<Object?, Object?>? raw = await channel
          .invokeMethod<Map<Object?, Object?>>(
            'geocodeDetail',
            <String, Object?>{'address': text, 'city': city.trim()},
          );
      if (raw == null) {
        return null;
      }
      final String province = '${raw['province'] ?? ''}'.trim();
      final String resolvedCity = '${raw['city'] ?? ''}'.trim();
      final String district = '${raw['district'] ?? ''}'.trim();
      final double latitude = (raw['latitude'] as num?)?.toDouble() ?? 0;
      final double longitude = (raw['longitude'] as num?)?.toDouble() ?? 0;
      if (province.isEmpty && resolvedCity.isEmpty && district.isEmpty) {
        return null;
      }
      return (
        province: province,
        city: resolvedCity,
        district: district,
        latitude: latitude,
        longitude: longitude,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 定位按钮：回到设备当前位置，返回 `moved` / `locating` / `permission` 等状态。
  static Future<String> recenter() async {
    if (!isSupported) {
      return 'unsupported';
    }
    final String status =
        await channel.invokeMethod<String>('recenter') ?? 'starting';
    return status;
  }

  /// 把镜头移动到指定坐标并打点。
  static Future<bool> moveTo({
    required double latitude,
    required double longitude,
    required String title,
  }) async {
    if (!isSupported) {
      return false;
    }
    final String? status = await channel.invokeMethod<String>(
      'moveTo',
      <String, Object>{'lat': latitude, 'lng': longitude, 'title': title},
    );
    return status == 'moved';
  }

  /// 同步联系人头像标记：只有带经纬度的联系人才会出现在地图上。
  ///
  /// [pins] 每项为 `{id, lat, lng, name, avatar: Uint8List?}`。
  static Future<void> setContacts(List<Map<String, Object?>> pins) async {
    if (!isSupported) {
      return;
    }
    try {
      await channel.invokeMethod<void>('contacts', <String, Object>{
        'pins': pins,
      });
    } on MissingPluginException {
      // 原生还没就绪，下次重建再同步。
    } on PlatformException {
      // 忽略：地图标记不影响主流程。
    }
  }

  static List<AmapPlace> _places(List<Object?>? raw) => <AmapPlace>[
    for (final Object? item in raw ?? <Object?>[])
      if (item is Map) _placeFromMap(item),
  ];

  static AmapPlace _placeFromMap(Map<Object?, Object?> map) {
    double readDouble(Object? value) => switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text) ?? 0,
      _ => 0,
    };
    final Object? distance = map['distance'];
    return AmapPlace(
      title: '${map['title'] ?? ''}',
      snippet: '${map['snippet'] ?? ''}',
      latitude: readDouble(map['lat']),
      longitude: readDouble(map['lng']),
      distanceMeters: switch (distance) {
        final num value => value.round(),
        final String value => int.tryParse(value),
        _ => null,
      },
    );
  }

  static AmapDistrict _districtFromMap(Map<Object?, Object?> map) {
    double readDouble(Object? value) => switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text) ?? 0,
      _ => 0,
    };
    return AmapDistrict(
      name: '${map['name'] ?? ''}',
      adcode: '${map['adcode'] ?? ''}',
      level: '${map['level'] ?? ''}',
      latitude: readDouble(map['lat']),
      longitude: readDouble(map['lng']),
    );
  }
}

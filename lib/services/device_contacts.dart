import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;

/// 手机通讯录里的一条记录（只取姓名与号码，够填充联系人即可）。
class DeviceContact {
  const DeviceContact({
    required this.id,
    required this.name,
    required this.phones,
  });

  final String id;
  final String name;
  final List<String> phones;

  String get primaryPhone => phones.isEmpty ? '' : phones.first;

  /// 导入时用的展示名：没名字就退回号码。
  String get displayName => name.isEmpty ? primaryPhone : name;
}

/// 读取系统通讯录；需要 READ_CONTACTS 运行时权限。
class DeviceContacts {
  const DeviceContacts._();

  static const MethodChannel channel = MethodChannel(
    'io.stardito.nullmap/device',
  );

  /// 返回通讯录列表；权限被拒绝时返回 null，平台不支持时返回空列表。
  static Future<List<DeviceContact>?> read() async {
    try {
      final List<Object?>? raw = await channel.invokeMethod<List<Object?>>(
        'readContacts',
      );
      if (raw == null) {
        return null;
      }
      return <DeviceContact>[
        for (final Object? item in raw)
          if (item is Map<Object?, Object?>)
            DeviceContact(
              id: '${item['id'] ?? ''}',
              name: '${item['name'] ?? ''}'.trim(),
              phones: <String>[
                for (final Object? phone
                    in (item['phones'] as List<Object?>? ?? const <Object?>[]))
                  if (phone != null && '$phone'.trim().isNotEmpty)
                    '$phone'.trim(),
              ],
            ),
      ];
    } on MissingPluginException {
      return const <DeviceContact>[];
    } on PlatformException {
      return null;
    }
  }
}

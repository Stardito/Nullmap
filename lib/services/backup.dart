import 'dart:convert';

import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;

import '../core/app_settings.dart';
import '../data/contact.dart';
import '../data/contact_store.dart';

/// 备份/恢复结果：成功时 [count] 是联系人条数，导出时 [path] 是保存位置。
class BackupResult {
  const BackupResult({this.path, this.count = 0, this.error});

  final String? path;
  final int count;
  final String? error;

  bool get ok => error == null;
}

/// 备份与恢复：把联系人与设置打包成一个 JSON 文件，经系统文件选择器读写。
///
/// 文件读写放在原生侧（`io.stardito.nullmap/security` 通道）：
/// 导出走 MediaStore 的 Downloads 目录，导入走 ACTION_OPEN_DOCUMENT。
class BackupService {
  const BackupService._();

  static const MethodChannel channel = MethodChannel(
    'io.stardito.nullmap/security',
  );

  static const int schemaVersion = 1;

  /// 导出全部数据；[settings] 里的隐私开关也会一起带走。
  static Future<BackupResult> export({
    required ContactStore store,
    required AppSettings settings,
  }) async {
    final Map<String, Object?> payload = <String, Object?>{
      'app': 'nullmap',
      'schema': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'contacts': <Map<String, Object?>>[
        for (final Contact contact in store.contacts) contact.toJson(),
      ],
      'settings': settings.toBackup(),
    };
    final String content = const JsonEncoder.withIndent('  ').convert(payload);
    try {
      final String? path = await channel.invokeMethod<String>(
        'exportBackup',
        <String, Object?>{
          'filename': 'nullmap-${_stamp()}.json',
          'content': content,
        },
      );
      if (path == null || path.isEmpty) {
        return const BackupResult(error: 'save');
      }
      return BackupResult(path: path, count: store.contacts.length);
    } on PlatformException catch (error) {
      return BackupResult(error: error.message ?? error.code);
    } on MissingPluginException {
      return const BackupResult(error: 'unsupported');
    }
  }

  /// 选择备份文件并恢复：联系人整体替换，设置按文件里存在的项覆盖。
  static Future<BackupResult> restore({
    required ContactStore store,
    required AppSettings settings,
  }) async {
    final String? content;
    try {
      content = await channel.invokeMethod<String>('importBackup');
    } on PlatformException catch (error) {
      return BackupResult(error: error.message ?? error.code);
    } on MissingPluginException {
      return const BackupResult(error: 'unsupported');
    }
    if (content == null || content.trim().isEmpty) {
      return const BackupResult(error: 'empty');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return const BackupResult(error: 'format');
    }
    if (decoded is! Map) {
      return const BackupResult(error: 'format');
    }
    final Object? rawContacts = decoded['contacts'];
    if (rawContacts is! List) {
      return const BackupResult(error: 'format');
    }
    final List<Contact> contacts = rawContacts
        .map(Contact.fromJson)
        .whereType<Contact>()
        .toList(growable: false);
    final Object? rawSettings = decoded['settings'];
    if (rawSettings is Map) {
      await settings.applyBackup(<String, Object?>{
        for (final MapEntry<Object?, Object?> entry in rawSettings.entries)
          '${entry.key}': entry.value,
      });
    }
    store.replaceAll(contacts);
    return BackupResult(count: contacts.length);
  }

  static String _stamp() {
    final DateTime now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

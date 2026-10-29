import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../data/contact.dart';

/// 头像字节缓存，key 为「本地路径 + 修改时间」或 QQ 头像地址。
final Map<String, Uint8List?> _cache = <String, Uint8List?>{};

/// 取联系人头像的原始字节：本地图片 > QQ 头像 > null（由调用方画首字母）。
///
/// 供地图标记与取色使用；网络失败不抛异常，直接返回 null。
Future<Uint8List?> contactAvatarBytes(Contact contact) async {
  final String localPath = contact.avatarPath.trim();
  if (localPath.isNotEmpty) {
    try {
      final File file = File(localPath);
      if (file.existsSync()) {
        final String key =
            'file:$localPath:${file.statSync().modified.millisecondsSinceEpoch}';
        if (_cache.containsKey(key)) {
          return _cache[key];
        }
        final Uint8List bytes = await file.readAsBytes();
        _cache[key] = bytes;
        return bytes;
      }
    } on FileSystemException {
      // 读不到就退回 QQ / 首字母。
    }
  }

  final String? url = contact.qqAvatarUrl;
  if (url == null) {
    return null;
  }
  if (_cache.containsKey(url)) {
    return _cache[url];
  }
  final Uint8List? bytes = await _download(url);
  _cache[url] = bytes;
  return bytes;
}

Future<Uint8List?> _download(String url) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);
  try {
    final HttpClientRequest request = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 4));
    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 6),
    );
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in response.timeout(
      const Duration(seconds: 6),
    )) {
      builder.add(chunk);
    }
    final Uint8List bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  } on Exception {
    return null;
  } finally {
    client.close(force: true);
  }
}

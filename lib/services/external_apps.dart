import 'package:url_launcher/url_launcher.dart';

/// 唤起外部 App 的小工具。
class ExternalApps {
  const ExternalApps._();

  /// 打开 QQ 个人名片。
  ///
  /// 优先用 `mqqapi` 名片页，失败后回退到聊天页 scheme；
  /// 两个都失败（例如没装 QQ）返回 false。
  static Future<bool> openQqProfile(String qq) async {
    final String target = qq.trim();
    if (target.isEmpty) {
      return false;
    }
    final List<Uri> candidates = <Uri>[
      Uri.parse(
        'mqqapi://card/show_pslcard?src_type=internal&version=1&uin=$target&card_type=person',
      ),
      Uri.parse(
        'mqq://im/chat?chat_type=wpa&uin=$target&version=1&src_type=web',
      ),
    ];
    for (final Uri uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } on Exception {
        // 换下一个 scheme。
      }
    }
    return false;
  }

  /// 拨打电话。
  static Future<bool> call(String phone) async {
    final String target = phone.replaceAll(RegExp(r'\s+'), '');
    if (target.isEmpty) {
      return false;
    }
    try {
      return await launchUrl(Uri(scheme: 'tel', path: target));
    } on Exception {
      return false;
    }
  }
}

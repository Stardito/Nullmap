import 'dart:io';

import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:material_ui/material_ui.dart';

import '../data/contact.dart';

/// 屏幕锁验证：借系统的「确认锁屏密码 / 指纹」页面确认是本人。
///
/// 原生侧用 `KeyguardManager.createConfirmDeviceCredentialIntent` 拉起系统验证，
/// 不依赖额外权限，也不会拿到任何生物特征数据。
class DeviceAuth {
  const DeviceAuth._();

  static const MethodChannel channel = MethodChannel(
    'io.stardito.nullmap/security',
  );

  /// 测试注入：返回 true 表示验证通过。
  static Future<bool> Function()? override;

  /// 设备是否已经设置锁屏（没设置就没法验证，只能提示用户先去设置）。
  static Future<bool> isSecure() async {
    if (override != null) {
      return true;
    }
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await channel.invokeMethod<bool>('isSecure') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 拉起系统验证；返回是否通过（用户取消算失败）。
  static Future<bool> verify({String reason = ''}) async {
    if (override != null) {
      return override!();
    }
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await channel.invokeMethod<bool>('authenticate', <String, Object?>{
            'reason': reason,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// 会话级解锁状态：解锁一次后一直有效，直到进程被系统回收（清后台）。
///
/// 不落任何持久化存储，保证「清掉后台就重新上锁」。
class PrivacyGate extends ChangeNotifier {
  PrivacyGate._();

  static final PrivacyGate instance = PrivacyGate._();

  bool _unlocked = false;

  bool get unlocked => _unlocked;

  void unlock() {
    if (_unlocked) {
      return;
    }
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    if (!_unlocked) {
      return;
    }
    _unlocked = false;
    notifyListeners();
  }

  /// 弹屏幕锁验证，通过后进入解锁状态；已经解锁时直接返回 true。
  Future<bool> requestUnlock(
    BuildContext context, {
    required String reason,
    required String noLockMessage,
    required String failedMessage,
  }) async {
    if (_unlocked) {
      return true;
    }
    final bool ok = await requireDeviceUnlock(
      context,
      reason: reason,
      noLockMessage: noLockMessage,
      failedMessage: failedMessage,
    );
    if (ok) {
      unlock();
    }
    return ok;
  }
}

/// 敏感信息脱敏：只保留辨认所需的头尾字符。
class Redaction {
  const Redaction._();

  static const String _dots = '••••';

  /// 手机号：前 3 位 + 后 4 位，例如 `138****8000`。
  static String phone(String value) {
    final String text = value.trim();
    if (text.isEmpty) {
      return text;
    }
    if (text.length <= 7) {
      return _dots;
    }
    final int tail = text.length >= 8 ? 4 : 2;
    return '${text.substring(0, 3)}$_dots${text.substring(text.length - tail)}';
  }

  /// QQ / 微信号：前 2 位 + 后 1 位，例如 `12****1`。
  static String account(String value) {
    final String text = value.trim();
    if (text.isEmpty) {
      return text;
    }
    if (text.length <= 4) {
      return _dots;
    }
    return '${text.substring(0, 2)}$_dots${text.substring(text.length - 1)}';
  }

  /// 姓名：只留姓，例如 `张**`。
  static String name(String value) {
    final String text = value.trim();
    if (text.isEmpty) {
      return text;
    }
    if (text.length == 1) {
      return '${text.substring(0, 1)}*';
    }
    return '${text.substring(0, 1)}${'*' * (text.length - 1)}';
  }

  /// 地址：整段替换，避免从省市区推断出具体住处。
  static String place(String value) => value.trim().isEmpty ? value : '••••••';
}

/// 需要验证时的统一入口：没有锁屏、验证失败都会给出提示。///
/// 返回 true 表示可以继续；[onReveal] 只在通过后执行。
Future<bool> requireDeviceUnlock(
  BuildContext context, {
  required String reason,
  required String noLockMessage,
  required String failedMessage,
}) async {
  if (!await DeviceAuth.isSecure()) {
    if (context.mounted) {
      _toast(context, noLockMessage);
    }
    return false;
  }
  final bool ok = await DeviceAuth.verify(reason: reason);
  if (!ok && context.mounted) {
    _toast(context, failedMessage);
  }
  return ok;
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// 显示名在「隐藏敏感信息」时的替代：昵称本来就当标题展示，只有退回
/// 姓名 / QQ / 微信 / 手机号时才需要脱敏。
extension SensitiveContact on Contact {
  String maskedDisplayName() {
    if (nickname.trim().isNotEmpty) {
      return nickname.trim();
    }
    if (name.trim().isNotEmpty) {
      return Redaction.name(name);
    }
    if (qq.trim().isNotEmpty) {
      return Redaction.account(qq);
    }
    if (wechat.trim().isNotEmpty) {
      return Redaction.account(wechat);
    }
    if (phone.trim().isNotEmpty) {
      return Redaction.phone(phone);
    }
    return '';
  }

  /// 列表 / 概览用的一行摘要，锁定状态下手机号与地址都要脱敏。
  String maskedSummary({required bool locked}) {
    final List<String> parts = <String>[
      if (phone.trim().isNotEmpty)
        locked ? Redaction.phone(phone) : phone.trim(),
      if (locationText.isNotEmpty)
        locked ? Redaction.place(locationText) : locationText,
    ];
    return parts.join(' · ');
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nullmap/core/app_info.dart';

void main() {
  test('AppInfo 版本与 pubspec.yaml 保持一致', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'^version:\s*(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml 缺少 version 字段');
    expect(match!.group(1), '${AppInfo.version}+${AppInfo.buildNumber}');
  });

  test('AppInfo 的「关于」信息完整', () {
    expect(AppInfo.appNameFull, contains(AppInfo.appName));
    expect(AppInfo.versionLabel, '${AppInfo.version} (${AppInfo.buildNumber})');
    expect(AppInfo.developer, isNotEmpty);
    expect(AppInfo.repositoryUrl, startsWith('https://github.com/'));
  });
}

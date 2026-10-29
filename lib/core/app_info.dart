/// 项目元信息的唯一来源。
///
/// 程序名、版本、开发者、仓库地址都只在这里定义，界面与「关于」页面
/// 一律从这里读取，避免多处硬编码后不一致。
/// `test/app_info_test.dart` 会校验 [version]/[buildNumber] 与 pubspec.yaml 一致。
abstract final class AppInfo {
  /// 中文程序名。
  static const String appName = '零点地图';

  /// 完整程序名（中英文）。
  static const String appNameFull = '零点地图-NullMap';

  /// 语义化版本号，与 pubspec.yaml 的 `version:` 前半段一致。
  static const String version = '1.0.1';

  /// 构建号，与 pubspec.yaml 的 `version:` 后半段一致。
  static const String buildNumber = '16';

  /// 形如 `0.1.0 (2)`，用于「关于」页面展示。
  static const String versionLabel = '$version ($buildNumber)';

  /// 开发者。
  static const String developer = 'Stardito';

  /// 开源仓库地址。
  static const String repositoryUrl = 'https://github.com/Stardito/Nullmap';

  /// 仓库地址的展示文本。
  static const String repositoryLabel = 'Stardito/Nullmap';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navMap => '地图';

  @override
  String get navContacts => '联系人';

  @override
  String get navSettings => '设置';

  @override
  String get mapSearchHint => '搜索地点';

  @override
  String get mapSearchEmpty => '没有找到地点';

  @override
  String mapDistanceAway(String distance) {
    return '距您 $distance';
  }

  @override
  String get mapLayerHint => '在设置中切换地图样式';

  @override
  String get mapSearchFailed => '搜索失败，请稍后重试';

  @override
  String mapSearchJumped(String title) {
    return '已定位到「$title」';
  }

  @override
  String get mapLocateTooltip => '定位';

  @override
  String get mapLocateBack => '已回到当前位置';

  @override
  String get mapLocatePending => '正在定位…';

  @override
  String get mapLocateStarting => '地图还在加载，请稍后再试';

  @override
  String get mapLocateUnavailable => '无法获取位置，请检查定位权限与系统定位开关';

  @override
  String get mapLocateUnsupported => '当前设备不支持定位，请在 arm64 真机上运行';

  @override
  String get contactsSearchHint => '搜索姓名、QQ、微信、电话或所在地';

  @override
  String get contactsEmpty => '没有匹配的联系人';

  @override
  String get contactsEmptyList => '还没有联系人，点右下角新增';

  @override
  String get contactsAdd => '新增联系人';

  @override
  String get contactsEdit => '编辑';

  @override
  String get contactsDelete => '删除';

  @override
  String get contactsDeleteTitle => '删除联系人';

  @override
  String contactsDeleteBody(String name) {
    return '确定删除「$name」吗？此操作不可撤销。';
  }

  @override
  String get contactsSaved => '已保存';

  @override
  String get contactsDeleted => '已删除';

  @override
  String get contactsCancel => '取消';

  @override
  String get contactsSave => '保存';

  @override
  String get contactName => '姓名';

  @override
  String get contactNickname => '昵称';

  @override
  String get contactQq => 'QQ 号';

  @override
  String get contactWechat => '微信号';

  @override
  String get contactPhone => '手机号';

  @override
  String get contactLocation => '所在地';

  @override
  String get contactCountry => '国家';

  @override
  String get contactProvince => '省';

  @override
  String get contactCity => '市';

  @override
  String get contactDistrict => '区/县';

  @override
  String get contactAddress => '详细地址';

  @override
  String get contactAddressHint => '小区 / 楼宇 / 街道，可从候选中选择';

  @override
  String locationPickTitle(String label) {
    return '选择$label';
  }

  @override
  String get locationPickEmpty => '未获取到候选，请检查网络后重试';

  @override
  String get locationPickUnsupported => '仅 Android 支持高德候选';

  @override
  String get contactAvatar => '头像';

  @override
  String get contactAvatarPick => '选择图片';

  @override
  String get contactAvatarQq => '使用 QQ 头像';

  @override
  String get contactAvatarMissing => '还没有头像';

  @override
  String get contactQqOpen => '打开 QQ 名片';

  @override
  String get contactQqOpenFailed => '未安装 QQ 或无法打开';

  @override
  String get contactCall => '拨打';

  @override
  String get contactNotFilled => '未填写';

  @override
  String get contactNeedOne => '至少填写一项：姓名、昵称、QQ、微信或手机号';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsLanguage => '显示语言';

  @override
  String get settingsLanguageDialogTitle => '显示语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsAppearance => '外观与显示';

  @override
  String get appearanceTheme => '主题';

  @override
  String get appearanceThemeMode => '明暗模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get appearanceThemeColor => '主题颜色';

  @override
  String get themeColorDynamic => '跟随壁纸';

  @override
  String get themeColorBlue => '蓝色';

  @override
  String get themeColorGreen => '绿色';

  @override
  String get themeColorOrange => '橙色';

  @override
  String get themeColorPurple => '紫色';

  @override
  String get themeColorTeal => '青色';

  @override
  String get themeColorRed => '红色';

  @override
  String get settingsMapGroup => '地图';

  @override
  String get settingsMapStyle => '地图样式';

  @override
  String get mapStyleStandard => '标准';

  @override
  String get mapStyleSatellite => '卫星';

  @override
  String get mapStyleTerrain => '地形';

  @override
  String get settingsAbout => '关于项目';

  @override
  String get aboutAppName => '程序名';

  @override
  String get aboutAppVersion => '程序版本';

  @override
  String get aboutDeveloper => '开发者';

  @override
  String get aboutRepository => '开源仓库';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get mapContactsTitle => '选择联系人';

  @override
  String get mapContactOverview => '联系人概览';

  @override
  String get contactViewDetail => '查看联系人详情';

  @override
  String get mapSearchContactsHint => '搜索联系人';

  @override
  String get mapSearchContactsEmpty => '没有匹配的联系人';

  @override
  String get mapContactNoLocation => '该联系人还没有坐标，无法定位';

  @override
  String get contactManualInput => '手动输入';

  @override
  String get contactManualInputHint => '输入名称';

  @override
  String get contactCountryCommon => '常用国家/地区';

  @override
  String get contactViewOnMap => '在地图上查看';

  @override
  String get contactsFilterAll => '全部';

  @override
  String get settingsRegionAlerts => '所在地区提醒';

  @override
  String get settingsRegionAlertsSubtitle => '定位到的地区变化时，告诉你那里有多少位联系人';

  @override
  String get settingsRegionGranularity => '判断粒度';

  @override
  String get regionGranularityProvince => '省';

  @override
  String get regionGranularityCity => '市';

  @override
  String get regionGranularityDistrict => '区';

  @override
  String regionAlertTitle(int count, String region) {
    return '$count 位联系人在$region';
  }

  @override
  String regionAlertBody(String region) {
    return '点击查看并筛选$region的联系人';
  }

  @override
  String get settingsPrivacy => '隐私与安全';

  @override
  String get privacyLock => '隐藏敏感信息';

  @override
  String get privacyLockSubtitle => '手机号、姓名、QQ / 微信与地址默认打码';

  @override
  String get privacyLockOn => '已开启';

  @override
  String get privacyLockOff => '未开启';

  @override
  String get privacyLockMap => '地图也需要验证';

  @override
  String get privacyLockMapSubtitle => '查看地图前先通过屏幕锁，联系人位置不会提前渲染';

  @override
  String get privacyLockHint => '解锁在当前会话内有效，清除后台后重新上锁。';

  @override
  String get privacyUnlock => '解锁';

  @override
  String get privacyLockNow => '上锁';

  @override
  String get privacyUnlockReason => '验证以查看敏感信息';

  @override
  String get privacyEditReason => '验证以编辑联系人';

  @override
  String get privacyToggleReason => '验证以修改隐私设置';

  @override
  String get privacyBackupReason => '验证以备份或恢复数据';

  @override
  String get privacyNoDeviceLock => '请先在系统设置中设置锁屏密码';

  @override
  String get privacyAuthFailed => '验证未通过';

  @override
  String get privacyBackup => '备份与恢复';

  @override
  String get privacyBackupSubtitle => '导出联系人与设置为 JSON 文件，或从文件恢复';

  @override
  String get privacyExport => '导出数据';

  @override
  String privacyExportSubtitle(Object count) {
    return '共 $count 位联系人';
  }

  @override
  String privacyExportDone(Object count, Object path) {
    return '已导出 $count 位联系人到 $path';
  }

  @override
  String get privacyImport => '导入数据';

  @override
  String get privacyImportSubtitle => '从备份文件恢复，会覆盖现有联系人';

  @override
  String get privacyImportConfirmTitle => '导入并覆盖？';

  @override
  String get privacyImportConfirmBody => '导入后现有联系人会被备份文件中的联系人替换，此操作无法撤销。';

  @override
  String privacyImportDone(Object count) {
    return '已恢复 $count 位联系人';
  }

  @override
  String get privacyImportInvalid => '备份文件格式不正确';

  @override
  String get privacyImportCanceled => '没有选择文件';

  @override
  String get privacyBackupFailed => '备份操作失败';

  @override
  String get privacyBackupUnsupported => '当前平台不支持备份';

  @override
  String get contactTags => '标签';

  @override
  String get contactTagAdd => '添加标签';

  @override
  String get contactTagHint => '例如 家人 / 同事';

  @override
  String get contactTagEmpty => '还没有标签，点「添加标签」创建一个。';

  @override
  String get mapFilterTag => '标签';

  @override
  String get privacyMapLockedTitle => '地图已隐藏';

  @override
  String get privacyMapLockedBody => '已开启隐私锁，验证后才能查看地图与联系人位置。';

  @override
  String get privacyMapUnlock => '验证并查看';

  @override
  String get privacyCallReason => '验证后拨打';

  @override
  String get contactTagExisting => '已有标签';

  @override
  String get contactAddressAutoHint => '输入完整地址后，省 / 市 / 区会自动补全';
}

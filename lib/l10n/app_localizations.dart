import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @navMap.
  ///
  /// In zh, this message translates to:
  /// **'地图'**
  String get navMap;

  /// No description provided for @navContacts.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get navContacts;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @mapSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索地点'**
  String get mapSearchHint;

  /// No description provided for @mapSearchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到地点'**
  String get mapSearchEmpty;

  /// No description provided for @mapDistanceAway.
  ///
  /// In zh, this message translates to:
  /// **'距您 {distance}'**
  String mapDistanceAway(String distance);

  /// No description provided for @mapLayerHint.
  ///
  /// In zh, this message translates to:
  /// **'在设置中切换地图样式'**
  String get mapLayerHint;

  /// No description provided for @mapSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败，请稍后重试'**
  String get mapSearchFailed;

  /// No description provided for @mapSearchJumped.
  ///
  /// In zh, this message translates to:
  /// **'已定位到「{title}」'**
  String mapSearchJumped(String title);

  /// No description provided for @mapLocateTooltip.
  ///
  /// In zh, this message translates to:
  /// **'定位'**
  String get mapLocateTooltip;

  /// No description provided for @mapLocateBack.
  ///
  /// In zh, this message translates to:
  /// **'已回到当前位置'**
  String get mapLocateBack;

  /// No description provided for @mapLocatePending.
  ///
  /// In zh, this message translates to:
  /// **'正在定位…'**
  String get mapLocatePending;

  /// No description provided for @mapLocateStarting.
  ///
  /// In zh, this message translates to:
  /// **'地图还在加载，请稍后再试'**
  String get mapLocateStarting;

  /// No description provided for @mapLocateUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法获取位置，请检查定位权限与系统定位开关'**
  String get mapLocateUnavailable;

  /// No description provided for @mapLocateUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持定位，请在 arm64 真机上运行'**
  String get mapLocateUnsupported;

  /// No description provided for @contactsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索姓名、QQ、微信、电话或所在地'**
  String get contactsSearchHint;

  /// No description provided for @contactsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的联系人'**
  String get contactsEmpty;

  /// No description provided for @contactsEmptyList.
  ///
  /// In zh, this message translates to:
  /// **'还没有联系人，点右下角新增'**
  String get contactsEmptyList;

  /// No description provided for @contactsAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增联系人'**
  String get contactsAdd;

  /// No description provided for @contactsEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get contactsEdit;

  /// No description provided for @contactsDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get contactsDelete;

  /// No description provided for @contactsDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除联系人'**
  String get contactsDeleteTitle;

  /// No description provided for @contactsDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？此操作不可撤销。'**
  String contactsDeleteBody(String name);

  /// No description provided for @contactsSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get contactsSaved;

  /// No description provided for @contactsDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get contactsDeleted;

  /// No description provided for @contactsCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get contactsCancel;

  /// No description provided for @contactsSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get contactsSave;

  /// No description provided for @contactName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get contactName;

  /// No description provided for @contactNickname.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get contactNickname;

  /// No description provided for @contactQq.
  ///
  /// In zh, this message translates to:
  /// **'QQ 号'**
  String get contactQq;

  /// No description provided for @contactWechat.
  ///
  /// In zh, this message translates to:
  /// **'微信号'**
  String get contactWechat;

  /// No description provided for @contactPhone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get contactPhone;

  /// No description provided for @contactLocation.
  ///
  /// In zh, this message translates to:
  /// **'所在地'**
  String get contactLocation;

  /// No description provided for @contactCountry.
  ///
  /// In zh, this message translates to:
  /// **'国家'**
  String get contactCountry;

  /// No description provided for @contactProvince.
  ///
  /// In zh, this message translates to:
  /// **'省'**
  String get contactProvince;

  /// No description provided for @contactCity.
  ///
  /// In zh, this message translates to:
  /// **'市'**
  String get contactCity;

  /// No description provided for @contactDistrict.
  ///
  /// In zh, this message translates to:
  /// **'区/县'**
  String get contactDistrict;

  /// No description provided for @contactAddress.
  ///
  /// In zh, this message translates to:
  /// **'详细地址'**
  String get contactAddress;

  /// No description provided for @contactAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'小区 / 楼宇 / 街道，可从候选中选择'**
  String get contactAddressHint;

  /// No description provided for @locationPickTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择{label}'**
  String locationPickTitle(String label);

  /// No description provided for @locationPickEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未获取到候选，请检查网络后重试'**
  String get locationPickEmpty;

  /// No description provided for @locationPickUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'仅 Android 支持高德候选'**
  String get locationPickUnsupported;

  /// No description provided for @contactAvatar.
  ///
  /// In zh, this message translates to:
  /// **'头像'**
  String get contactAvatar;

  /// No description provided for @contactAvatarPick.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get contactAvatarPick;

  /// No description provided for @contactAvatarQq.
  ///
  /// In zh, this message translates to:
  /// **'使用 QQ 头像'**
  String get contactAvatarQq;

  /// No description provided for @contactAvatarMissing.
  ///
  /// In zh, this message translates to:
  /// **'还没有头像'**
  String get contactAvatarMissing;

  /// No description provided for @contactQqOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开 QQ 名片'**
  String get contactQqOpen;

  /// No description provided for @contactQqOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'未安装 QQ 或无法打开'**
  String get contactQqOpenFailed;

  /// No description provided for @contactCall.
  ///
  /// In zh, this message translates to:
  /// **'拨打'**
  String get contactCall;

  /// No description provided for @contactNotFilled.
  ///
  /// In zh, this message translates to:
  /// **'未填写'**
  String get contactNotFilled;

  /// No description provided for @contactNeedOne.
  ///
  /// In zh, this message translates to:
  /// **'至少填写一项：姓名、昵称、QQ、微信或手机号'**
  String get contactNeedOne;

  /// No description provided for @settingsGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsGeneral;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'显示语言'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示语言'**
  String get settingsLanguageDialogTitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观与显示'**
  String get settingsAppearance;

  /// No description provided for @appearanceTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get appearanceTheme;

  /// No description provided for @appearanceThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'明暗模式'**
  String get appearanceThemeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @appearanceThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题颜色'**
  String get appearanceThemeColor;

  /// No description provided for @themeColorDynamic.
  ///
  /// In zh, this message translates to:
  /// **'跟随壁纸'**
  String get themeColorDynamic;

  /// No description provided for @themeColorBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝色'**
  String get themeColorBlue;

  /// No description provided for @themeColorGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿色'**
  String get themeColorGreen;

  /// No description provided for @themeColorOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙色'**
  String get themeColorOrange;

  /// No description provided for @themeColorPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫色'**
  String get themeColorPurple;

  /// No description provided for @themeColorTeal.
  ///
  /// In zh, this message translates to:
  /// **'青色'**
  String get themeColorTeal;

  /// No description provided for @themeColorRed.
  ///
  /// In zh, this message translates to:
  /// **'红色'**
  String get themeColorRed;

  /// No description provided for @settingsMapGroup.
  ///
  /// In zh, this message translates to:
  /// **'地图'**
  String get settingsMapGroup;

  /// No description provided for @settingsMapStyle.
  ///
  /// In zh, this message translates to:
  /// **'地图样式'**
  String get settingsMapStyle;

  /// No description provided for @mapStyleStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get mapStyleStandard;

  /// No description provided for @mapStyleSatellite.
  ///
  /// In zh, this message translates to:
  /// **'卫星'**
  String get mapStyleSatellite;

  /// No description provided for @mapStyleTerrain.
  ///
  /// In zh, this message translates to:
  /// **'地形'**
  String get mapStyleTerrain;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于项目'**
  String get settingsAbout;

  /// No description provided for @aboutAppName.
  ///
  /// In zh, this message translates to:
  /// **'程序名'**
  String get aboutAppName;

  /// No description provided for @aboutAppVersion.
  ///
  /// In zh, this message translates to:
  /// **'程序版本'**
  String get aboutAppVersion;

  /// No description provided for @aboutDeveloper.
  ///
  /// In zh, this message translates to:
  /// **'开发者'**
  String get aboutDeveloper;

  /// No description provided for @aboutRepository.
  ///
  /// In zh, this message translates to:
  /// **'开源仓库'**
  String get aboutRepository;

  /// No description provided for @aboutLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get aboutLicenses;

  /// No description provided for @mapContactsTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择联系人'**
  String get mapContactsTitle;

  /// No description provided for @mapContactOverview.
  ///
  /// In zh, this message translates to:
  /// **'联系人概览'**
  String get mapContactOverview;

  /// No description provided for @contactViewDetail.
  ///
  /// In zh, this message translates to:
  /// **'查看联系人详情'**
  String get contactViewDetail;

  /// No description provided for @mapSearchContactsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索联系人'**
  String get mapSearchContactsHint;

  /// No description provided for @mapSearchContactsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的联系人'**
  String get mapSearchContactsEmpty;

  /// No description provided for @mapContactNoLocation.
  ///
  /// In zh, this message translates to:
  /// **'该联系人还没有坐标，无法定位'**
  String get mapContactNoLocation;

  /// No description provided for @contactManualInput.
  ///
  /// In zh, this message translates to:
  /// **'手动输入'**
  String get contactManualInput;

  /// No description provided for @contactManualInputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入名称'**
  String get contactManualInputHint;

  /// No description provided for @contactCountryCommon.
  ///
  /// In zh, this message translates to:
  /// **'常用国家/地区'**
  String get contactCountryCommon;

  /// No description provided for @contactViewOnMap.
  ///
  /// In zh, this message translates to:
  /// **'在地图上查看'**
  String get contactViewOnMap;

  /// No description provided for @contactsFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get contactsFilterAll;

  /// No description provided for @settingsRegionAlerts.
  ///
  /// In zh, this message translates to:
  /// **'所在地区提醒'**
  String get settingsRegionAlerts;

  /// No description provided for @settingsRegionAlertsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'定位到的地区变化时，告诉你那里有多少位联系人'**
  String get settingsRegionAlertsSubtitle;

  /// No description provided for @settingsRegionGranularity.
  ///
  /// In zh, this message translates to:
  /// **'判断粒度'**
  String get settingsRegionGranularity;

  /// No description provided for @regionGranularityProvince.
  ///
  /// In zh, this message translates to:
  /// **'省'**
  String get regionGranularityProvince;

  /// No description provided for @regionGranularityCity.
  ///
  /// In zh, this message translates to:
  /// **'市'**
  String get regionGranularityCity;

  /// No description provided for @regionGranularityDistrict.
  ///
  /// In zh, this message translates to:
  /// **'区'**
  String get regionGranularityDistrict;

  /// No description provided for @regionAlertTitle.
  ///
  /// In zh, this message translates to:
  /// **'{count} 位联系人在{region}'**
  String regionAlertTitle(int count, String region);

  /// No description provided for @regionAlertBody.
  ///
  /// In zh, this message translates to:
  /// **'点击查看并筛选{region}的联系人'**
  String regionAlertBody(String region);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

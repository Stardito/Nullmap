// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navMap => 'Map';

  @override
  String get navContacts => 'Contacts';

  @override
  String get navSettings => 'Settings';

  @override
  String get mapSearchHint => 'Search places';

  @override
  String get mapSearchEmpty => 'No places found';

  @override
  String mapDistanceAway(String distance) {
    return '$distance away';
  }

  @override
  String get mapLayerHint => 'Switch map style in Settings';

  @override
  String get mapSearchFailed => 'Search failed. Try again later.';

  @override
  String mapSearchJumped(String title) {
    return 'Moved to “$title”';
  }

  @override
  String get mapLocateTooltip => 'Locate';

  @override
  String get mapLocateBack => 'Back to current location';

  @override
  String get mapLocatePending => 'Locating…';

  @override
  String get mapLocateStarting =>
      'Map is still loading. Try again in a moment.';

  @override
  String get mapLocateUnavailable =>
      'Cannot get location. Check location permission and system location switch.';

  @override
  String get mapLocateUnsupported =>
      'Location is not supported on this device. Run on an arm64 device.';

  @override
  String get contactsSearchHint => 'Search name, QQ, WeChat, phone or location';

  @override
  String get contactsEmpty => 'No matching contacts';

  @override
  String get contactsEmptyList =>
      'No contacts yet. Tap the button at bottom right to add one.';

  @override
  String get contactsAdd => 'New contact';

  @override
  String get contactsEdit => 'Edit';

  @override
  String get contactsDelete => 'Delete';

  @override
  String get contactsDeleteTitle => 'Delete contact';

  @override
  String contactsDeleteBody(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get contactsSaved => 'Saved';

  @override
  String get contactsDeleted => 'Deleted';

  @override
  String get contactsCancel => 'Cancel';

  @override
  String get contactsSave => 'Save';

  @override
  String get contactName => 'Name';

  @override
  String get contactNickname => 'Nickname';

  @override
  String get contactQq => 'QQ';

  @override
  String get contactWechat => 'WeChat';

  @override
  String get contactPhone => 'Phone';

  @override
  String get contactLocation => 'Location';

  @override
  String get contactCountry => 'Country';

  @override
  String get contactProvince => 'Province';

  @override
  String get contactCity => 'City';

  @override
  String get contactDistrict => 'District';

  @override
  String get contactAddress => 'Address';

  @override
  String get contactAddressHint => 'Building / street, pick from suggestions';

  @override
  String locationPickTitle(String label) {
    return 'Choose $label';
  }

  @override
  String get locationPickEmpty =>
      'No candidates. Check your network and retry.';

  @override
  String get locationPickUnsupported => 'AMap candidates are Android-only';

  @override
  String get contactAvatar => 'Avatar';

  @override
  String get contactAvatarPick => 'Choose image';

  @override
  String get contactAvatarQq => 'Use QQ avatar';

  @override
  String get contactAvatarMissing => 'No avatar yet';

  @override
  String get contactQqOpen => 'Open QQ profile';

  @override
  String get contactQqOpenFailed => 'QQ is not installed or cannot be opened';

  @override
  String get contactCall => 'Call';

  @override
  String get contactNotFilled => 'Not set';

  @override
  String get contactNeedOne =>
      'Fill in at least one field: name, nickname, QQ, WeChat or phone';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageDialogTitle => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow system';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsAppearance => 'Appearance & display';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceThemeMode => 'Appearance';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get appearanceThemeColor => 'Theme color';

  @override
  String get themeColorDynamic => 'Wallpaper';

  @override
  String get themeColorBlue => 'Blue';

  @override
  String get themeColorGreen => 'Green';

  @override
  String get themeColorOrange => 'Orange';

  @override
  String get themeColorPurple => 'Purple';

  @override
  String get themeColorTeal => 'Teal';

  @override
  String get themeColorRed => 'Red';

  @override
  String get settingsMapGroup => 'Map';

  @override
  String get settingsMapStyle => 'Map style';

  @override
  String get mapStyleStandard => 'Standard';

  @override
  String get mapStyleSatellite => 'Satellite';

  @override
  String get mapStyleTerrain => 'Terrain';

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutAppName => 'App name';

  @override
  String get aboutAppVersion => 'Version';

  @override
  String get aboutDeveloper => 'Developer';

  @override
  String get aboutRepository => 'Repository';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get mapContactsTitle => 'Choose a contact';

  @override
  String get mapContactOverview => 'Contact overview';

  @override
  String get contactViewDetail => 'View contact details';

  @override
  String get mapSearchContactsHint => 'Search contacts';

  @override
  String get mapSearchContactsEmpty => 'No matching contacts';

  @override
  String get mapContactNoLocation => 'This contact has no coordinates yet';

  @override
  String get contactManualInput => 'Enter manually';

  @override
  String get contactManualInputHint => 'Enter a name';

  @override
  String get contactCountryCommon => 'Common countries/regions';

  @override
  String get contactViewOnMap => 'View on map';

  @override
  String get contactsFilterAll => 'All';

  @override
  String get settingsRegionAlerts => 'Region alerts';

  @override
  String get settingsRegionAlertsSubtitle =>
      'Tell me how many contacts are nearby when my region changes';

  @override
  String get settingsRegionGranularity => 'Match level';

  @override
  String get regionGranularityProvince => 'Province';

  @override
  String get regionGranularityCity => 'City';

  @override
  String get regionGranularityDistrict => 'District';

  @override
  String regionAlertTitle(int count, String region) {
    return '$count contacts in $region';
  }

  @override
  String regionAlertBody(String region) {
    return 'Tap to view and filter contacts in $region';
  }
}

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'app_settings.dart';

/// 显示语言的文案名。
String languageLabel(AppLocalizations l10n, Locale? locale) =>
    switch (locale?.languageCode) {
      'zh' => l10n.settingsLanguageChinese,
      'en' => l10n.settingsLanguageEnglish,
      _ => l10n.settingsLanguageSystem,
    };

/// 地图样式的文案名。
String mapStyleLabel(AppLocalizations l10n, MapStyle style) => switch (style) {
  MapStyle.standard => l10n.mapStyleStandard,
  MapStyle.satellite => l10n.mapStyleSatellite,
  MapStyle.terrain => l10n.mapStyleTerrain,
};

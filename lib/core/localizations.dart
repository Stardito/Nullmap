import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// 应用本地化委托。
///
/// 注意：Material/Cupertino 委托必须用 `material_ui` 自带的那一份
/// （[GlobalMaterialLocalizations.delegates]）。换成 `flutter_localizations`
/// 的实现会因类型不同而报 "No MaterialLocalizations found"，中文
/// Material 文案也不会生效。
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

/// 应用支持的语言：简体中文、English。
const List<Locale> appSupportedLocales = AppLocalizations.supportedLocales;

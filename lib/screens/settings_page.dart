import 'package:material_ui/material_ui.dart';

import '../core/app_info.dart';
import '../core/app_settings.dart';
import '../core/l10n_labels.dart';
import '../l10n/app_localizations.dart';
import 'settings_about_page.dart';
import 'settings_appearance_page.dart';
import 'settings_general_page.dart';

/// 设置页入口：通用 / 外观与显示 / 关于项目，各自进入子页面。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = AppSettingsScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.settingsGeneral),
            subtitle: Text(languageLabel(l10n, settings.locale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SettingsGeneralPage()),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsAppearance),
            subtitle: Text(mapStyleLabel(l10n, settings.mapStyle)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SettingsAppearancePage()),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(AppInfo.versionLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SettingsAboutPage()),
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

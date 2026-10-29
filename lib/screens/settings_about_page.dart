import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../l10n/app_localizations.dart';

/// 关于项目子页：程序名、版本、开发者、开源仓库、开源许可。
class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Image(
                image: AssetImage('assets/icon/app_icon.png'),
                width: 104,
                height: 104,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.apps),
                  title: Text(l10n.aboutAppName),
                  subtitle: Text(AppInfo.appNameFull),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.aboutAppVersion),
                  subtitle: Text(AppInfo.versionLabel),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.aboutDeveloper),
                  subtitle: Text(AppInfo.developer),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(l10n.aboutRepository),
                  subtitle: Text(AppInfo.repositoryLabel),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openRepository(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.aboutLicenses),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppInfo.appNameFull,
                    applicationVersion: AppInfo.versionLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRepository(BuildContext context) async {
    final bool ok = await launchUrl(
      Uri.parse(AppInfo.repositoryUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppInfo.repositoryUrl),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

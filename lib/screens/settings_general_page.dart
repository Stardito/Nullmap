import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';
import '../core/l10n_labels.dart';
import '../l10n/app_localizations.dart';

/// 通用设置子页：显示语言。
class SettingsGeneralPage extends StatelessWidget {
  const SettingsGeneralPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = AppSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsGeneral)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.translate_outlined),
              title: Text(l10n.settingsLanguage),
              subtitle: Text(languageLabel(l10n, settings.locale)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickLanguage(context, settings, l10n),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  secondary: const Icon(Icons.travel_explore),
                  title: Text(l10n.settingsRegionAlerts),
                  subtitle: Text(l10n.settingsRegionAlertsSubtitle),
                  value: settings.regionAlertsEnabled,
                  onChanged: (bool enabled) =>
                      settings.setRegionAlertsEnabled(enabled),
                ),
                if (settings.regionAlertsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.settingsRegionGranularity,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<RegionGranularity>(
                          segments: <ButtonSegment<RegionGranularity>>[
                            ButtonSegment<RegionGranularity>(
                              value: RegionGranularity.province,
                              label: Text(l10n.regionGranularityProvince),
                            ),
                            ButtonSegment<RegionGranularity>(
                              value: RegionGranularity.city,
                              label: Text(l10n.regionGranularityCity),
                            ),
                            ButtonSegment<RegionGranularity>(
                              value: RegionGranularity.district,
                              label: Text(l10n.regionGranularityDistrict),
                            ),
                          ],
                          selected: <RegionGranularity>{
                            settings.regionGranularity,
                          },
                          onSelectionChanged: (
                            Set<RegionGranularity> selection,
                          ) => settings.setRegionGranularity(selection.first),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    AppSettings settings,
    AppLocalizations l10n,
  ) async {
    final List<(String, String)> options = <(String, String)>[
      ('system', l10n.settingsLanguageSystem),
      ('zh', l10n.settingsLanguageChinese),
      ('en', l10n.settingsLanguageEnglish),
    ];
    final String current = switch (settings.locale?.languageCode) {
      'zh' => 'zh',
      'en' => 'en',
      _ => 'system',
    };

    // 返回 String：对话框被点击外部关闭时为 null，据此区分「跟随系统」。
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.settingsLanguageDialogTitle),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (String code, String label) in options)
              ListTile(
                title: Text(label),
                trailing: code == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ),
    );

    if (!context.mounted || picked == null) {
      return;
    }
    await settings.setLocale(picked == 'system' ? null : Locale(picked));
  }
}

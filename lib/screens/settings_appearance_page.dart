import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 外观与显示子页：主题（明暗模式 / 配色）与地图样式。
class SettingsAppearancePage extends StatelessWidget {
  const SettingsAppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = AppSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppearance)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.appearanceTheme,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.appearanceThemeMode,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text(l10n.themeModeSystem),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text(l10n.themeModeLight),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeModeDark),
                      ),
                    ],
                    selected: <ThemeMode>{settings.themeMode},
                    onSelectionChanged: (Set<ThemeMode> selection) =>
                        settings.setThemeMode(selection.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appearanceThemeColor,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (final ThemeSeed seed in ThemeSeed.values)
                        _SeedSwatch(
                          seed: seed,
                          label: _seedLabel(l10n, seed),
                          selected: settings.themeSeed == seed,
                          onTap: () => settings.setThemeSeed(seed),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.settingsMapGroup,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.settingsMapStyle, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<MapStyle>(
                    segments: <ButtonSegment<MapStyle>>[
                      ButtonSegment<MapStyle>(
                        value: MapStyle.standard,
                        label: Text(l10n.mapStyleStandard),
                      ),
                      ButtonSegment<MapStyle>(
                        value: MapStyle.satellite,
                        label: Text(l10n.mapStyleSatellite),
                      ),
                      ButtonSegment<MapStyle>(
                        value: MapStyle.terrain,
                        label: Text(l10n.mapStyleTerrain),
                      ),
                    ],
                    selected: <MapStyle>{settings.mapStyle},
                    onSelectionChanged: (Set<MapStyle> selection) =>
                        settings.setMapStyle(selection.first),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _seedLabel(AppLocalizations l10n, ThemeSeed seed) =>
      switch (seed) {
        ThemeSeed.dynamic => l10n.themeColorDynamic,
        ThemeSeed.blue => l10n.themeColorBlue,
        ThemeSeed.green => l10n.themeColorGreen,
        ThemeSeed.orange => l10n.themeColorOrange,
        ThemeSeed.purple => l10n.themeColorPurple,
        ThemeSeed.teal => l10n.themeColorTeal,
        ThemeSeed.red => l10n.themeColorRed,
      };
}

/// 单个配色选项：圆形色块，选中时显示对勾。
class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.seed,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeSeed seed;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = seed == ThemeSeed.dynamic
        ? theme.colorScheme.secondary
        : AppTheme.seedOf(seed);
    final Color onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: seed == ThemeSeed.dynamic
                ? Icon(Icons.wallpaper, size: 20, color: onColor)
                : selected
                ? Icon(Icons.check, size: 20, color: onColor)
                : null,
          ),
        ),
      ),
    );
  }
}

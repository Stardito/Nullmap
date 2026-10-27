import 'package:material_ui/material_ui.dart';

/// 设置页。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notify = true;
  bool _autoSync = true;
  bool _locationAlways = false;
  int _mapStyle = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('通用', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('通知'),
                subtitle: const Text('节点状态与消息提醒'),
                value: _notify,
                onChanged: (bool v) => setState(() => _notify = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.sync_outlined),
                title: const Text('自动同步'),
                subtitle: const Text('仅在 Wi-Fi 下同步数据'),
                value: _autoSync,
                onChanged: (bool v) => setState(() => _autoSync = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('地图', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('地图样式', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('标准')),
                    ButtonSegment(value: 1, label: Text('卫星')),
                    ButtonSegment(value: 2, label: Text('地形')),
                  ],
                  selected: {_mapStyle},
                  onSelectionChanged: (Set<int> s) =>
                      setState(() => _mapStyle = s.first),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.my_location_outlined),
                  title: const Text('始终获取位置'),
                  subtitle: const Text('关闭后仅在应用内定位'),
                  value: _locationAlways,
                  onChanged: (bool v) => setState(() => _locationAlways = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('关于', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('版本'),
                subtitle: Text('0.1.0 (1)'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('开源许可'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'NullMap',
                  applicationVersion: '0.1.0',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

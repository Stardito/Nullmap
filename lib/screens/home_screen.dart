import 'package:material_ui/material_ui.dart';

import 'contacts_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

/// 底部导航宿主：地图 / 联系人 / 设置。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _titles = ['地图', '联系人', '设置'];

  int _index = 0;

  Widget? get _fab => switch (_index) {
    0 => FloatingActionButton(
      tooltip: '定位',
      onPressed: () => _toast('已回到当前位置'),
      child: const Icon(Icons.my_location),
    ),
    1 => FloatingActionButton(
      tooltip: '新增联系人',
      onPressed: () => _toast('新增联系人'),
      child: const Icon(Icons.person_add_alt),
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [MapPage(), ContactsPage(), SettingsPage()],
        ),
      ),
      floatingActionButton: _fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '地图',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '联系人',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

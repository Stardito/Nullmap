import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../data/contact.dart';
import '../services/region_alerts.dart';
import 'contact_edit_page.dart';
import 'contacts_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

/// 全局入口：别的页面可以通过它切到地图并定位某个联系人。
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

/// 底部导航宿主：地图 / 联系人 / 设置。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GlobalKey<MapPageState> _mapKey = GlobalKey<MapPageState>();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 通知在界面建好前就被点开时，先记着，等这里建好再套用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RegionSelection? pending = pendingRegionSelection;
      if (pending != null) {
        pendingRegionSelection = null;
        showRegionContacts(pending);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> titles = <String>[
      l10n.navMap,
      l10n.navContacts,
      l10n.navSettings,
    ];

    return Scaffold(
      // 键盘弹出时不改变 body 高度：地图 PlatformView 一旦跟着缩放，
      // 会连续几帧被拉扁（"一顿一顿变扁"），体验很差。
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(titles[_index])),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 地图始终留在树里并保持可见：PlatformView 一旦被隐藏/重新布局，
            // 恢复显示时会用旧纹理撑几秒（画面被拉扁），所以不做 IndexedStack 隐藏。
            MapPage(key: _mapKey),
            Offstage(
              offstage: _index == 0,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: IndexedStack(
                  index: _index == 2 ? 1 : 0,
                  children: const <Widget>[ContactsPage(), SettingsPage()],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(l10n),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l10n.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.navContacts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }

  Widget? _buildFab(AppLocalizations l10n) => switch (_index) {
    0 => FloatingActionButton(
      tooltip: l10n.mapLocateTooltip,
      onPressed: () => _mapKey.currentState?.moveToLocation(),
      child: const Icon(Icons.my_location),
    ),
    1 => FloatingActionButton(
      tooltip: l10n.contactsAdd,
      onPressed: _createContact,
      child: const Icon(Icons.person_add_alt),
    ),
    _ => null,
  };

  /// 切到地图页并把镜头移到该联系人，然后拉起概览面板。
  void showContactOnMap(Contact contact) {
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.showContact(contact);
    });
  }

  /// 切到联系人页并套用地区筛选（通知点击时调用）。
  void showRegionContacts(RegionSelection selection) {
    setState(() => _index = 1);
    regionSelectionRequest.value = selection;
  }

  Future<void> _createContact() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ContactEditPage()),
    );
    if (saved == true && mounted) {
      _toast(AppLocalizations.of(context).contactsSaved);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

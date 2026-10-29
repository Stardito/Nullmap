import 'dart:async' show Timer, unawaited;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodCall, StandardMessageCodec;
import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';
import '../data/contact.dart';
import '../data/contact_store.dart';
import '../l10n/app_localizations.dart';
import '../services/amap_service.dart';
import '../services/avatar_bytes.dart';
import '../services/monet.dart';
import 'settings_appearance_page.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/map_contact_sheet.dart';

/// 地图页：高德底图 + 定位按钮 + 地点搜索。
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  /// 与 `MainActivity` 注册的 PlatformView 类型保持一致。
  static const String amapViewType = 'io.stardito.nullmap/amap';

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Contact> _results = <Contact>[];
  bool _searched = false;

  /// 中性描边色：头像取色失败时使用，也是融合 20% 莫奈色的底色。
  int _neutralRing = 0xFFF1F3F4;

  /// 上一次推给原生的联系人标记签名，避免重复同步。
  String _pinSignature = '';
  bool _syncingPins = false;
  List<Contact>? _pendingPins;

  /// 行政区中心点缓存，key 为「级别:名称」；只缓存成功结果，失败留给重试。
  final Map<String, ({double latitude, double longitude})> _regionCenters =
      <String, ({double latitude, double longitude})>{};
  bool _backfilling = false;

  /// 地图视图可能还没就绪，补全失败时延迟重试；上限避免无网时无限请求。
  Timer? _backfillRetry;
  int _backfillAttempts = 0;
  static const int _maxBackfillAttempts = 5;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      // 原生把被点中的标记（联系人 id 列表）回调回来，由 Flutter 用 M3 底部面板展示。
      AmapService.channel.setMethodCallHandler(_onNativeCall);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _neutralRing =
        (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3C4043)
                : const Color(0xFFF1F3F4))
            .toARGB32();
    _syncContactPins();
    unawaited(_backfillRegionCenters());
  }

  @override
  void dispose() {
    _backfillRetry?.cancel();
    if (Platform.isAndroid) {
      AmapService.channel.setMethodCallHandler(null);
    }
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method != 'markerTap') {
      return null;
    }
    final Object? arguments = call.arguments;
    final List<String> ids = <String>[
      if (arguments is Map && arguments['ids'] is List)
        for (final Object? id in arguments['ids'] as List) '$id',
    ].where((String id) => id.isNotEmpty).toList();
    if (mounted && ids.isNotEmpty) {
      _showContactSheet(ids);
    }
    return null;
  }

  void _showContactSheet(List<String> ids) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => MapContactSheet(contactIds: ids),
    );
  }

  /// 回到设备当前位置，由原生侧负责权限与定位失败提示。
  Future<void> moveToLocation() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String status = await AmapService.recenter();
    if (!mounted) {
      return;
    }
    switch (status) {
      case 'moved':
        _toast(l10n.mapLocateBack);
      case 'locating':
        _toast(l10n.mapLocatePending);
      case 'starting':
        _toast(l10n.mapLocateStarting);
      case 'permission':
        _toast(l10n.mapLocateUnavailable);
      case 'unsupported':
        _toast(l10n.mapLocateUnsupported);
      default:
        _toast(l10n.mapLocatePending);
    }
  }

  /// 搜索联系人：命中姓名 / 昵称 / QQ / 微信 / 电话 / 所在地。
  void _searchContacts() {
    final String keyword = _search.text.trim();
    _searchFocus.unfocus();
    if (keyword.isEmpty) {
      setState(() {
        _results = <Contact>[];
        _searched = false;
      });
      return;
    }
    final String needle = keyword.toLowerCase();
    final List<Contact> contacts = ContactScope.of(context).contacts;
    final List<Contact> matches = <Contact>[
      for (final Contact contact in contacts)
        if (<String>[
          contact.name,
          contact.nickname,
          contact.qq,
          contact.wechat,
          contact.phone,
          contact.locationText,
        ].any((String value) => value.toLowerCase().contains(needle)))
          contact,
    ];
    setState(() {
      _results = matches;
      _searched = true;
    });
  }

  /// 选中联系人：地图移过去，并拉起 M3 联系人概览。
  Future<void> _openContact(Contact contact) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() {
      _results = <Contact>[];
      _searched = false;
    });
    Contact target = contact;
    if (!target.isLocatable) {
      // 旧数据可能只有省/市/区：点开时补一次行政区中心点。
      final ({double latitude, double longitude})? center =
          await _regionCenterFor(target);
      if (!mounted) {
        return;
      }
      if (center != null) {
        target = target.copyWith(
          regionLatitude: center.latitude,
          regionLongitude: center.longitude,
        );
        ContactScope.of(context).update(target);
      }
    }
    final double? latitude = target.mapLatitude;
    final double? longitude = target.mapLongitude;
    if (latitude == null || longitude == null) {
      // 行政区也解析不到坐标：只提示，不改镜头。
      _toast(l10n.mapContactNoLocation);
      return;
    }
    await AmapService.moveTo(
      latitude: latitude,
      longitude: longitude,
      title: target.displayName,
    );
    if (!mounted) {
      return;
    }
    _showContactSheet(<String>[target.id]);
  }

  /// 供外部（联系人详情）调用：定位到该联系人并弹概览。
  Future<void> showContact(Contact contact) => _openContact(contact);

  void _openStyleSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsAppearancePage(),
      ),
    );
  }

  void _clearSearch() {
    _search.clear();
    setState(() {
      _results = <Contact>[];
      _searched = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 联系人最细一级的行政区；都没有时 keyword 为空串。
  static ({String level, String keyword}) _regionSelector(Contact contact) {
    if (contact.district.trim().isNotEmpty) {
      return (level: 'district', keyword: contact.district.trim());
    }
    if (contact.city.trim().isNotEmpty) {
      return (level: 'city', keyword: contact.city.trim());
    }
    return (level: 'province', keyword: contact.province.trim());
  }

  /// 解析行政区中心点，按「级别:名称」缓存；平台不支持或查不到时返回 null。
  Future<({double latitude, double longitude})?> _regionCenterFor(
    Contact contact,
  ) async {
    final ({String level, String keyword}) selector = _regionSelector(contact);
    if (selector.keyword.isEmpty) {
      return null;
    }
    final String cacheKey = '${selector.level}:${selector.keyword}';
    final ({double latitude, double longitude})? cached =
        _regionCenters[cacheKey];
    if (cached != null) {
      return cached;
    }
    final ({double latitude, double longitude})? center =
        await AmapService.districtCenter(selector.keyword);
    if (center != null) {
      _regionCenters[cacheKey] = center;
    }
    return center;
  }

  /// 旧数据可能只精确到省/市/区：进地图时补全行政区中心并写回本地。
  ///
  /// 地图平台视图可能还没建好，此时原生查不到中心点；延迟重试几次，
  /// 失败上限避免无网络时一直请求。
  Future<void> _backfillRegionCenters() async {
    if (!Platform.isAndroid || _backfilling) {
      return;
    }
    _backfilling = true;
    bool failed = false;
    try {
      final ContactStore store = ContactScope.of(context);
      final List<Contact> pending = <Contact>[
        for (final Contact contact in store.contacts)
          if (!contact.isLocatable &&
              _regionSelector(contact).keyword.isNotEmpty)
            contact,
      ];
      for (final Contact contact in pending) {
        final ({double latitude, double longitude})? center =
            await _regionCenterFor(contact);
        if (!mounted) {
          return;
        }
        if (center == null) {
          failed = true;
          continue;
        }
        final Contact? current = store.byId(contact.id);
        // 解析期间记录可能已被删除，或已由别处补上坐标。
        if (current == null || current.isLocatable) {
          continue;
        }
        store.update(
          current.copyWith(
            regionLatitude: center.latitude,
            regionLongitude: center.longitude,
          ),
        );
      }
    } finally {
      _backfilling = false;
    }
    if (!mounted) {
      return;
    }
    if (!failed) {
      _backfillAttempts = 0;
      return;
    }
    if (_backfillAttempts >= _maxBackfillAttempts) {
      return;
    }
    _backfillAttempts++;
    _backfillRetry?.cancel();
    _backfillRetry = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        unawaited(_backfillRegionCenters());
      }
    });
  }

  /// 把「有坐标的联系人」推给原生画成圆形头像标记。
  ///
  /// 坐标优先取详细地址，其次退回省/市/区中心；只同步变化过的数据，
  /// 原生侧会缓存最后一批标记，切换地图样式重建视图后自动恢复。
  void _syncContactPins() {
    if (!Platform.isAndroid) {
      return;
    }
    final ContactStore store = ContactScope.of(context);
    final List<Contact> located = <Contact>[
      for (final Contact contact in store.contacts)
        if (contact.isLocatable) contact,
    ];
    final String signature = located
        .map(
          (Contact contact) =>
              '${contact.id}|${contact.mapLatitude}|${contact.mapLongitude}|'
              '${contact.displayName}|${contact.avatarPath}|${contact.qq}',
        )
        .join(';');
    if (signature == _pinSignature) {
      return;
    }
    _pinSignature = signature;
    if (_syncingPins) {
      _pendingPins = located;
      return;
    }
    unawaited(_pushPins(located));
  }

  Future<void> _pushPins(List<Contact> contacts) async {
    _syncingPins = true;
    try {
      final List<Map<String, Object?>> pins = <Map<String, Object?>>[];
      for (final Contact contact in contacts) {
        final Uint8List? avatar = await contactAvatarBytes(contact);
        // 描边 = 头像莫奈色 20% 叠在中性色上；取不到色就用中性色。
        int ring = _neutralRing;
        if (avatar != null) {
          final Color? seed = await monetColorFromImage(avatar);
          if (seed != null) {
            ring = Color.alphaBlend(
              seed.withValues(alpha: 0.20),
              Color(_neutralRing),
            ).toARGB32();
          }
        }
        pins.add(<String, Object?>{
          'id': contact.id,
          'lat': contact.mapLatitude,
          'lng': contact.mapLongitude,
          'name': contact.displayName,
          'avatar': avatar,
          'ring': ring,
        });
      }
      await AmapService.setContacts(pins);
    } finally {
      _syncingPins = false;
      final List<Contact>? pending = _pendingPins;
      _pendingPins = null;
      if (pending != null) {
        unawaited(_pushPins(pending));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MapStyle style = AppSettingsScope.of(context).mapStyle;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 头像描边用中性灰：纯黑在暗色模式里太重，浅色模式也不抢眼。
    final int ring =
        (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3C4043)
                : const Color(0xFFF1F3F4))
            .toARGB32();
    final int primary = scheme.primary.toARGB32();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            controller: _search,
            focusNode: _searchFocus,
            hintText: l10n.mapSearchContactsHint,
            leading: const Icon(Icons.search),
            trailing: <Widget>[
              if (_search.text.isNotEmpty)
                IconButton(
                  tooltip: l10n.contactsCancel,
                  icon: const Icon(Icons.close),
                  onPressed: _clearSearch,
                ),
              IconButton(
                tooltip: l10n.mapLayerHint,
                icon: const Icon(Icons.layers_outlined),
                onPressed: _openStyleSettings,
              ),
            ],
            onSubmitted: (_) => _searchContacts(),
          ),
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Platform.isAndroid
                    ? AndroidView(
                        // 样式/描边/主题色只能通过 creationParams 传给原生，必须换 key 才会重建视图。
                        key: ValueKey<String>('$ring-$primary-${style.index}'),
                        viewType: MapPage.amapViewType,
                        creationParams: <String, Object>{
                          'style': style.index,
                          'ring': ring,
                          'primary': primary,
                        },
                        creationParamsCodec: const StandardMessageCodec(),
                      )
                    : const _MapCanvas(),
              ),
              if (_results.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: _ContactResults(
                    contacts: _results,
                    onSelected: _openContact,
                  ),
                ),
              if (_searched && _results.isEmpty)
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.search_off),
                      title: Text(l10n.mapSearchContactsEmpty),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactResults extends StatelessWidget {
  const _ContactResults({required this.contacts, required this.onSelected});

  final List<Contact> contacts;
  final ValueChanged<Contact> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Card(
      elevation: 3,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: contacts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final Contact contact = contacts[index];
            final bool located = contact.isLocatable;
            final String subtitle = <String>[
              if (contact.phone.isNotEmpty) contact.phone,
              if (contact.locationText.isNotEmpty) contact.locationText,
              if (!located) l10n.mapContactNoLocation,
            ].join(' · ');
            return ListTile(
              leading: ContactAvatar(contact: contact, radius: 20),
              title: Text(
                contact.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: subtitle.isEmpty
                  ? null
                  : Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: located ? const Icon(Icons.my_location) : null,
              onTap: () => onSelected(contact),
            );
          },
        ),
      ),
    );
  }
}

/// 非 Android 平台的占位画布：经纬网格 + 三个示例点。
class _MapCanvas extends StatelessWidget {
  const _MapCanvas();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow),
      child: CustomPaint(painter: _GridPainter(scheme.outlineVariant)),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const double step = 48;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}

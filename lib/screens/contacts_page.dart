import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';
import '../data/contact.dart';
import '../data/contact_store.dart';
import '../l10n/app_localizations.dart';
import '../services/avatar_bytes.dart';
import '../services/external_apps.dart';
import '../services/monet.dart';
import '../services/privacy.dart';
import '../services/region_alerts.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/privacy_lock_button.dart';
import 'contact_edit_page.dart';
import 'home_screen.dart';

/// 联系人列表：支持按姓名 / 昵称 / QQ / 微信 / 手机号 / 所在地搜索。
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// 地区筛选：null 表示不限。
  String? _filterCountry;
  String? _filterProvince;
  String? _filterCity;
  String? _filterDistrict;

  @override
  void initState() {
    super.initState();
    regionSelectionRequest.addListener(_applyRegionRequest);
  }

  @override
  void dispose() {
    regionSelectionRequest.removeListener(_applyRegionRequest);
    _search.dispose();
    super.dispose();
  }

  /// 通知点击后套用地区筛选（国家不限，省/市按通知带来的值）。
  void _applyRegionRequest() {
    final RegionSelection? selection = regionSelectionRequest.value;
    if (!mounted || selection == null) {
      return;
    }
    setState(() {
      _filterCountry = null;
      _filterProvince = selection.province.isEmpty ? null : selection.province;
      _filterCity = selection.city.isEmpty ? null : selection.city;
      _filterDistrict = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 上锁/解锁会影响列表里的名称、手机号与地址，跟着 PrivacyGate 一起重建。
    return AnimatedBuilder(
      animation: PrivacyGate.instance,
      builder: (BuildContext context, Widget? child) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = AppSettingsScope.of(context);
    final bool locked = settings.privacyLock && !PrivacyGate.instance.unlocked;
    final List<Contact> contacts = ContactScope.of(context).contacts;

    String countryOf(Contact contact) {
      final String value = contact.country.trim();
      return value.isEmpty ? '中国' : value;
    }

    bool inCountry(Contact contact) =>
        _filterCountry == null || countryOf(contact) == _filterCountry;

    final List<String> countries = <String>{
      for (final Contact c in contacts) countryOf(c),
    }.toList()..sort();
    final List<String> provinces = <String>{
      for (final Contact c in contacts.where(inCountry))
        if (c.province.trim().isNotEmpty) c.province.trim(),
    }.toList()..sort();
    final List<String> cities = <String>{
      for (final Contact c in contacts.where(inCountry))
        if ((_filterProvince == null || c.province == _filterProvince) &&
            c.city.trim().isNotEmpty)
          c.city.trim(),
    }.toList()..sort();
    final List<String> districts = <String>{
      for (final Contact c in contacts.where(inCountry))
        if ((_filterProvince == null || c.province == _filterProvince) &&
            (_filterCity == null || c.city == _filterCity) &&
            c.district.trim().isNotEmpty)
          c.district.trim(),
    }.toList()..sort();

    final List<Contact> visible = contacts.where((Contact contact) {
      if (!inCountry(contact)) return false;
      if (_filterProvince != null && contact.province != _filterProvince) {
        return false;
      }
      if (_filterCity != null && contact.city != _filterCity) return false;
      if (_filterDistrict != null && contact.district != _filterDistrict) {
        return false;
      }
      if (_query.isNotEmpty && !_matches(contact, _query)) return false;
      return true;
    }).toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            controller: _search,
            hintText: l10n.contactsSearchHint,
            leading: const Icon(Icons.search),
            trailing: <Widget>[
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: l10n.contactsCancel,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
            onChanged: (String value) => setState(() => _query = value.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _regionChip(
                  label: l10n.contactCountry,
                  value: _filterCountry,
                  options: countries,
                  onPicked: (String? value) {
                    setState(() {
                      _filterCountry = value;
                      _filterProvince = null;
                      _filterCity = null;
                      _filterDistrict = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _regionChip(
                  label: l10n.contactProvince,
                  value: _filterProvince,
                  options: provinces,
                  onPicked: (String? value) {
                    setState(() {
                      _filterProvince = value;
                      _filterCity = null;
                      _filterDistrict = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _regionChip(
                  label: l10n.contactCity,
                  value: _filterCity,
                  options: cities,
                  onPicked: (String? value) {
                    setState(() {
                      _filterCity = value;
                      _filterDistrict = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _regionChip(
                  label: l10n.contactDistrict,
                  value: _filterDistrict,
                  options: districts,
                  onPicked: (String? value) {
                    setState(() => _filterDistrict = value);
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(isSearching: _query.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _ContactTile(
                      contact: visible[index],
                      locked: locked,
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool _matches(Contact contact, String query) {
    final String haystack = <String>[
      contact.name,
      contact.nickname,
      contact.qq,
      contact.wechat,
      contact.phone,
      contact.locationText,
    ].join(' ').toLowerCase();
    return haystack.contains(query.toLowerCase());
  }

  /// 一个地区筛选按钮：点开弹出候选项，选“全部”清除该级筛选。
  Widget _regionChip({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onPicked,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return FilterChip(
      selected: value != null,
      showCheckmark: false,
      avatar: Icon(value == null ? Icons.tune : Icons.place_outlined, size: 18),
      label: Text('$label: ${value ?? l10n.contactsFilterAll}'),
      onSelected: (_) => _pickRegion(
        title: label,
        options: options,
        current: value,
        onPicked: onPicked,
      ),
    );
  }

  Future<void> _pickRegion({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String?> onPicked,
  }) async {
    if (options.isEmpty) return;
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) =>
          _RegionSheet(title: title, options: options, current: current),
    );
    if (picked == null) return;
    onPicked(picked.isEmpty ? null : picked);
  }
}

/// 地区筛选候选项弹层；返回空字符串表示“全部”。
class _RegionSheet extends StatelessWidget {
  const _RegionSheet({
    required this.title,
    required this.options,
    required this.current,
  });

  final String title;
  final List<String> options;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.done_all),
            title: Text(l10n.contactsFilterAll),
            trailing: current == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(''),
          ),
          for (final String option in options)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(option),
              trailing: option == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isSearching ? Icons.search_off : Icons.people_outline,
              size: 56,
              color: scheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching ? l10n.contactsEmpty : l10n.contactsEmptyList,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.locked});

  final Contact contact;

  /// 开启隐私锁且当前会话未解锁：手机号、地址与姓名要打码。
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = locked
        ? contact.maskedDisplayName()
        : contact.displayName;
    final String summary = contact.maskedSummary(locked: locked);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ContactAvatar(contact: contact),
        title: Text(
          title.isEmpty ? l10n.contactNotFilled : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: summary.isEmpty
            ? null
            : Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                ContactDetailPage(contactId: contact.id),
          ),
        ),
      ),
    );
  }
}

/// 联系人详情：展示所有字段，并提供打开 QQ 名片、拨号、编辑、删除。
///
/// 背景为「头像 Monet 取色 → 默认背景」的竖向渐变。
class ContactDetailPage extends StatefulWidget {
  const ContactDetailPage({super.key, required this.contactId});

  final String contactId;

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  Color? _seed;
  String _seedKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSeed();
  }

  Future<void> _loadSeed() async {
    final Contact? contact = ContactScope.of(context).byId(widget.contactId);
    if (contact == null) {
      return;
    }
    final String key = '${contact.id}|${contact.avatarPath}|${contact.qq}';
    if (key == _seedKey) {
      return;
    }
    _seedKey = key;
    final Uint8List? bytes = await contactAvatarBytes(contact);
    final Color? seed = bytes == null ? null : await monetColorFromImage(bytes);
    if (!mounted) {
      return;
    }
    setState(() => _seed = seed);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PrivacyGate.instance,
      builder: (BuildContext context, Widget? child) => _buildDetail(context),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = AppSettingsScope.of(context);
    final bool locked = settings.privacyLock && !PrivacyGate.instance.unlocked;
    final ContactStore store = ContactScope.of(context);
    final Contact? contact = store.byId(widget.contactId);
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navContacts)),
        body: Center(child: Text(l10n.contactsEmpty)),
      );
    }

    final String location = contact.locationText;
    // 锁定状态下姓名、QQ、微信、手机号、地址全部打码；昵称仍是标题。
    final List<(String, String, String?)> rows = <(String, String, String?)>[
      (
        l10n.contactName,
        locked ? Redaction.name(contact.name) : contact.name,
        null,
      ),
      (l10n.contactNickname, contact.nickname, null),
      (
        l10n.contactQq,
        locked ? Redaction.account(contact.qq) : contact.qq,
        null,
      ),
      (
        l10n.contactWechat,
        locked ? Redaction.account(contact.wechat) : contact.wechat,
        null,
      ),
      (
        l10n.contactPhone,
        locked ? Redaction.phone(contact.phone) : contact.phone,
        l10n.contactCall,
      ),
      (
        l10n.contactLocation,
        locked ? Redaction.place(location) : location,
        null,
      ),
    ];

    /// 开启隐私锁时，编辑/删除/拨号前先过一遍屏幕锁。
    Future<bool> ensureUnlocked({String? reason}) async {
      if (!settings.privacyLock || PrivacyGate.instance.unlocked) {
        return true;
      }
      return PrivacyGate.instance.requestUnlock(
        context,
        reason: reason ?? l10n.privacyEditReason,
        noLockMessage: l10n.privacyNoDeviceLock,
        failedMessage: l10n.privacyAuthFailed,
      );
    }

    Future<void> delete() async {
      if (!await ensureUnlocked()) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(l10n.contactsDeleteTitle),
          content: Text(
            l10n.contactsDeleteBody(
              contact.displayName.isEmpty
                  ? l10n.contactNotFilled
                  : contact.displayName,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.contactsCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.contactsDelete),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      store.remove(contact.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.contactsDeleted)));
        Navigator.of(context).pop();
      }
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 莫奈取色只做轻量点缀：10% 不透明度叠在默认背景上，避免整屏被颜色压住。
    final Color tint = (_seed ?? scheme.primary).withValues(alpha: 0.30);
    final Color start = Color.alphaBlend(tint, scheme.surface);
    final Color onStart = scheme.onSurface;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onStart,
        title: Text(
          contact.displayName.isEmpty ? l10n.navContacts : contact.displayName,
        ),
        actions: <Widget>[
          const PrivacyLockButton(),
          IconButton(
            tooltip: l10n.contactsEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              if (!await ensureUnlocked()) {
                return;
              }
              if (!context.mounted) {
                return;
              }
              final bool? changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (BuildContext context) =>
                      ContactEditPage(contact: contact),
                ),
              );
              if (changed == true && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.contactsSaved)));
              }
            },
          ),
          IconButton(
            tooltip: l10n.contactsDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: delete,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[start, scheme.surface],
            stops: const <double>[0.0, 0.72],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 72,
            16,
            16,
          ),
          children: <Widget>[
            Center(child: ContactAvatar(contact: contact, radius: 44)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                contact.displayName.isEmpty
                    ? l10n.contactNotFilled
                    : contact.displayName,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: onStart),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: <Widget>[
                  for (int index = 0; index < rows.length; index++)
                    _DetailRow(
                      label: rows[index].$1,
                      value: rows[index].$2,
                      actionLabel: rows[index].$3,
                      onAction: rows[index].$3 == null
                          ? null
                          : () async {
                              // 隐私锁状态下，拨号同样要先过屏幕锁。
                              if (!await ensureUnlocked(
                                reason: l10n.privacyCallReason,
                              )) {
                                return;
                              }
                              await ExternalApps.call(contact.phone);
                            },
                      last: index == rows.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (contact.tags.isNotEmpty) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        l10n.contactTags,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      for (final String tag in contact.tags)
                        Chip(label: Text(tag)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context)
                    .popUntil((Route<void> route) => route.isFirst);
                homeScreenKey.currentState?.showContactOnMap(contact);
              },
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.contactViewOnMap),
            ),
            const SizedBox(height: 8),
            if (contact.qq.trim().isNotEmpty)
              FilledButton.icon(
                onPressed: () async {
                  final bool opened = await ExternalApps.openQqProfile(
                    contact.qq,
                  );
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.contactQqOpenFailed)),
                    );
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(l10n.contactQqOpen),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.last,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String value;
  final bool last;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String shown = value.trim().isEmpty ? l10n.contactNotFilled : value;
    return Column(
      children: <Widget>[
        ListTile(
          title: Text(label),
          subtitle: Text(shown),
          trailing: actionLabel == null
              ? null
              : TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ),
        if (!last) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

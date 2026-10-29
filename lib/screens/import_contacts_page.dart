import 'package:material_ui/material_ui.dart';

import '../data/contact.dart';
import '../data/contact_store.dart';
import '../l10n/app_localizations.dart';
import '../services/device_contacts.dart';

/// 从手机通讯录选择性导入联系人：列表勾选后一次性写入。
class ImportContactsPage extends StatefulWidget {
  const ImportContactsPage({super.key});

  @override
  State<ImportContactsPage> createState() => _ImportContactsPageState();
}

class _ImportContactsPageState extends State<ImportContactsPage> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = <String>{};

  List<DeviceContact> _items = <DeviceContact>[];
  bool _loading = true;
  bool _denied = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    final List<DeviceContact>? items = await DeviceContacts.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _denied = items == null;
      _items = items ?? <DeviceContact>[];
      _selected.clear();
    });
  }

  /// 号码归一化，用来判断是否已经存在（忽略空格、横线、+86）。
  static String _normalize(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('86') && digits.length > 11) {
      digits = digits.substring(2);
    }
    return digits;
  }

  Set<String> _existingPhones() {
    final ContactStore store = ContactScope.of(context);
    return <String>{
      for (final Contact contact in store.contacts)
        if (contact.phone.trim().isNotEmpty) _normalize(contact.phone),
    };
  }

  bool _isExisting(DeviceContact item, Set<String> existing) {
    for (final String phone in item.phones) {
      if (existing.contains(_normalize(phone))) {
        return true;
      }
    }
    return false;
  }

  List<DeviceContact> _visible(Set<String> existing) {
    final String query = _query.trim().toLowerCase();
    return <DeviceContact>[
      for (final DeviceContact item in _items)
        if (query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.phones.any((String phone) => phone.contains(query)))
          item,
    ];
  }

  Future<void> _import() async {
    final ContactStore store = ContactScope.of(context);
    final Set<String> existing = _existingPhones();
    int added = 0;
    for (final DeviceContact item in _items) {
      if (!_selected.contains(item.id) || _isExisting(item, existing)) {
        continue;
      }
      store.add(
        Contact(
          id: store.newId(),
          name: item.name.trim(),
          phone: item.primaryPhone,
        ),
      );
      added += 1;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(added);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Set<String> existing = _existingPhones();
    final List<DeviceContact> visible = _visible(existing);
    final int selectedCount = _selected.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importContactsTitle),
        actions: <Widget>[
          TextButton(
            onPressed: selectedCount == 0 ? null : _import,
            child: Text(l10n.importContactsAction(selectedCount)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denied
          ? _DeniedBody(onRetry: _load)
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: l10n.importContactsHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (String value) => setState(() => _query = value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: visible.isEmpty
                            ? null
                            : () => setState(() {
                                for (final DeviceContact item in visible) {
                                  if (!_isExisting(item, existing)) {
                                    _selected.add(item.id);
                                  }
                                }
                              }),
                        icon: const Icon(Icons.done_all),
                        label: Text(l10n.importContactsSelectAll),
                      ),
                      TextButton.icon(
                        onPressed: _selected.isEmpty
                            ? null
                            : () => setState(_selected.clear),
                        icon: const Icon(Icons.clear_all),
                        label: Text(l10n.importContactsClear),
                      ),
                      const Spacer(),
                      Text('$selectedCount / ${visible.length}'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: visible.isEmpty
                      ? Center(child: Text(l10n.importContactsEmpty))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (BuildContext context, int index) {
                            final DeviceContact item = visible[index];
                            final bool already = _isExisting(item, existing);
                            final bool checked = _selected.contains(item.id);
                            return CheckboxListTile(
                              value: checked || already,
                              onChanged: already
                                  ? null
                                  : (bool? value) => setState(() {
                                      if (value ?? false) {
                                        _selected.add(item.id);
                                      } else {
                                        _selected.remove(item.id);
                                      }
                                    }),
                              secondary: CircleAvatar(
                                child: Text(
                                  item.displayName.isEmpty
                                      ? '?'
                                      : item.displayName.substring(0, 1),
                                ),
                              ),
                              title: Text(item.displayName),
                              subtitle: Text(
                                already
                                    ? '${item.phones.join(' · ')} · '
                                          '${l10n.importContactsExisting}'
                                    : item.phones.join(' · '),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _DeniedBody extends StatelessWidget {
  const _DeniedBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.contacts_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(l10n.importContactsDenied, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.lock_open),
              label: Text(l10n.importContactsGrant),
            ),
          ],
        ),
      ),
    );
  }
}

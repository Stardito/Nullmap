import 'package:material_ui/material_ui.dart';

import '../data/contact.dart';
import '../data/contact_store.dart';
import '../l10n/app_localizations.dart';
import '../widgets/contact_avatar.dart';
import '../screens/contacts_page.dart' show ContactDetailPage;

/// 点击地图联系人标记后弹出的 Material 3 底部面板。
///
/// - 单个联系人：直接显示概览（昵称、电话、地址、详情入口）；
/// - 多个联系人重叠：先显示列表，选中后再进入概览。
class MapContactSheet extends StatefulWidget {
  const MapContactSheet({super.key, required this.contactIds});

  final List<String> contactIds;

  @override
  State<MapContactSheet> createState() => _MapContactSheetState();
}

class _MapContactSheetState extends State<MapContactSheet> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ContactStore store = ContactScope.of(context);
    final List<Contact> contacts = <Contact>[
      for (final String id in widget.contactIds)
        if (store.byId(id) case final Contact contact) contact,
    ];
    if (contacts.isEmpty) {
      return const SizedBox.shrink();
    }
    final Contact? selected = _selectedId == null
        ? (contacts.length == 1 ? contacts.first : null)
        : store.byId(_selectedId!);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (selected == null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  l10n.mapContactsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            else
              _OverviewHeader(
                title: selected.displayName.isEmpty
                    ? l10n.mapContactOverview
                    : selected.displayName,
                showBack: contacts.length > 1,
                onBack: () => setState(() => _selectedId = null),
              ),
            if (selected == null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: contacts.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Contact contact = contacts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ContactAvatar(contact: contact, radius: 22),
                      title: Text(
                        contact.displayName.isEmpty
                            ? l10n.navContacts
                            : contact.displayName,
                      ),
                      subtitle: Text(
                        _summary(l10n, contact),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() => _selectedId = contact.id),
                    );
                  },
                ),
              )
            else
              _OverviewBody(contact: selected),
          ],
        ),
      ),
    );
  }

  String _summary(AppLocalizations l10n, Contact contact) {
    final String location = contact.locationText;
    if (location.isNotEmpty) {
      return location;
    }
    return contact.phone.isEmpty ? l10n.contactNotFilled : contact.phone;
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: <Widget>[
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: ContactAvatar(contact: contact, radius: 36)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            contact.displayName,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: l10n.contactPhone,
          value: contact.phone.isEmpty ? l10n.contactNotFilled : contact.phone,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.place_outlined,
          label: l10n.contactLocation,
          value: contact.locationText.isEmpty
              ? l10n.contactNotFilled
              : contact.locationText,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            final NavigatorState navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    ContactDetailPage(contactId: contact.id),
              ),
            );
          },
          icon: const Icon(Icons.badge_outlined),
          label: Text(l10n.contactViewDetail),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

/// 联系人页：搜索 + 列表 + 详情。
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  static const List<Contact> _all = [
    Contact('陈默', '138 0000 1234', '产品'),
    Contact('林可', '139 1111 5678', '设计'),
    Contact('周远', '137 2222 9012', '开发'),
    Contact('苏晴', '136 3333 3456', '测试'),
    Contact('何川', '135 4444 7890', '运维'),
    Contact('许知', '134 5555 2345', '运营'),
  ];

  String _query = '';

  List<Contact> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (Contact c) =>
                  c.name.contains(_query) ||
                  c.phone.replaceAll(' ', '').contains(_query) ||
                  c.tag.contains(_query),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Contact> items = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchBar(
            hintText: '搜索姓名、电话或分组',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (String value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text('没有匹配的联系人', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final Contact c = items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: Text(c.name.characters.first),
                        ),
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        trailing: Chip(
                          label: Text(c.tag),
                          visualDensity: VisualDensity.compact,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ContactDetailPage(contact: c),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 联系人数据。
class Contact {
  const Contact(this.name, this.phone, this.tag);

  final String name;
  final String phone;
  final String tag;
}

/// 联系人详情页。
class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Contact c = contact;

    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(
                c.name.characters.first,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(c.name, style: theme.textTheme.headlineSmall)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              c.tag,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('电话'),
                  subtitle: Text(c.phone),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.mail_outline),
                  title: Text('邮箱'),
                  subtitle: Text('未填写'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.call),
            label: const Text('拨打'),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'contact.dart';

/// 联系人本地仓库：JSON 文件持久化 + 头像文件。
///
/// 默认存到应用文档目录（`contacts.json` 与 `avatars/`），
/// 测试时通过 [open] 的 `directory` 指定临时目录。
class ContactStore extends ChangeNotifier {
  ContactStore._(this._file, this._avatarDirectory);

  final File _file;
  final Directory _avatarDirectory;

  List<Contact> _contacts = <Contact>[];

  /// 落盘任务队列，保证写入顺序。
  Future<void> _writeQueue = Future<void>.value();

  List<Contact> get contacts => List<Contact>.unmodifiable(_contacts);

  bool get isEmpty => _contacts.isEmpty;

  /// 打开（或初始化）仓库并读取已有数据。
  static Future<ContactStore> open({Directory? directory}) async {
    final Directory base = directory ?? await getApplicationDocumentsDirectory();
    await base.create(recursive: true);
    final ContactStore store = ContactStore._(
      File('${base.path}${Platform.pathSeparator}contacts.json'),
      Directory('${base.path}${Platform.pathSeparator}avatars'),
    );
    await store._load();
    return store;
  }

  /// 文档目录不可用时的兜底：临时目录，行为一致但不保证长期保存。
  static Future<ContactStore> openFallback() async {
    final Directory temp = await getTemporaryDirectory();
    return open(
      directory: Directory(
        '${temp.path}${Platform.pathSeparator}nullmap_contacts',
      ),
    );
  }

  Future<void> _load() async {
    try {
      if (!await _file.exists()) {
        _contacts = <Contact>[];
        return;
      }
      final Object? decoded = jsonDecode(await _file.readAsString());
      if (decoded is! List) {
        _contacts = <Contact>[];
        return;
      }
      _contacts = decoded
          .map(Contact.fromJson)
          .whereType<Contact>()
          .toList(growable: true);
    } on Exception {
      // 数据损坏时按空列表处理，不阻塞启动。
      _contacts = <Contact>[];
    }
  }

  Future<void> _persist() async {
    await _file.writeAsString(
      jsonEncode(
        _contacts.map((Contact contact) => contact.toJson()).toList(),
      ),
      flush: true,
    );
  }

  /// 串行落盘：界面立即更新，写文件在后台排队，失败只记日志。
  void _schedulePersist() {
    _writeQueue = _writeQueue.then((_) => _persist()).catchError((
      Object error,
    ) {
      debugPrint('contacts persist failed: $error');
    });
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Contact? byId(String id) {
    for (final Contact contact in _contacts) {
      if (contact.id == id) {
        return contact;
      }
    }
    return null;
  }

  void add(Contact contact) {
    _contacts = <Contact>[..._contacts, contact];
    notifyListeners();
    _schedulePersist();
  }

  void update(Contact contact) {
    _contacts = <Contact>[
      for (final Contact item in _contacts)
        if (item.id == contact.id) contact else item,
    ];
    notifyListeners();
    _schedulePersist();
  }

  void remove(String id) {
    final Contact? target = byId(id);
    _contacts = _contacts.where((Contact item) => item.id != id).toList();
    notifyListeners();
    _schedulePersist();
    final String avatarPath = target?.avatarPath ?? '';
    if (avatarPath.isNotEmpty) {
      final File file = File(avatarPath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } on FileSystemException {
          // 头像删除失败不影响记录删除。
        }
      }
    }
  }

  /// 把选中的图片复制进应用目录，返回新路径。
  Future<String> saveAvatar(String contactId, File source) async {
    await _avatarDirectory.create(recursive: true);
    final String extension = _extensionOf(source.path);
    final File target = File(
      '${_avatarDirectory.path}${Platform.pathSeparator}$contactId$extension',
    );
    await source.copy(target.path);
    return target.path;
  }

  static String _extensionOf(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) {
      return '.jpg';
    }
    return path.substring(dot).toLowerCase();
  }
}

/// 把 [ContactStore] 下发给子树。
class ContactScope extends InheritedNotifier<ContactStore> {
  const ContactScope({
    super.key,
    required ContactStore store,
    required super.child,
  }) : super(notifier: store);

  static ContactStore of(BuildContext context) {
    final ContactScope? scope = context
        .dependOnInheritedWidgetOfExactType<ContactScope>();
    assert(scope != null, 'ContactScope 未在祖先节点中找到');
    return scope!.notifier!;
  }
}

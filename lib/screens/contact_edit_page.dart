import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/contact.dart';
import '../data/contact_store.dart';
import '../l10n/app_localizations.dart';
import '../services/amap_service.dart';
import '../widgets/contact_avatar.dart';

/// 新增 / 编辑联系人。
///
/// 所在地拆成国家 / 省 / 市 / 区县 / 详细地址：前三项从高德行政区划候选中选择，
/// 候选自带的中心点会一并保存，所以只精确到行政区的联系人也能在地图上打点；
/// 详细地址带高德输入提示，选中候选时记录更精确的坐标。
class ContactEditPage extends StatefulWidget {
  const ContactEditPage({super.key, this.contact});

  /// 为空表示新增。
  final Contact? contact;

  @override
  State<ContactEditPage> createState() => _ContactEditPageState();
}

class _ContactEditPageState extends State<ContactEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _nickname;
  late final TextEditingController _qq;
  late final TextEditingController _wechat;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  /// QQ 失焦后重建头像预览，立即加载该 QQ 号的头像。
  final FocusNode _qqFocus = FocusNode();

  String _country = '中国';
  String _province = '';
  String _city = '';
  String _district = '';
  double? _latitude;
  double? _longitude;

  /// 省 / 市 / 区县候选自带的中心点：没有详细地址时用它打点。
  double? _regionLatitude;
  double? _regionLongitude;

  String _avatarPath = '';
  File? _pickedAvatar;
  String? _error;

  List<AmapPlace> _addressTips = <AmapPlace>[];
  Timer? _tipsDebounce;
  bool _tipsLoading = false;

  @override
  void initState() {
    super.initState();
    final Contact? contact = widget.contact;
    _name = TextEditingController(text: contact?.name ?? '');
    _nickname = TextEditingController(text: contact?.nickname ?? '');
    _qq = TextEditingController(text: contact?.qq ?? '');
    _wechat = TextEditingController(text: contact?.wechat ?? '');
    _phone = TextEditingController(text: contact?.phone ?? '');
    _address = TextEditingController(text: contact?.address ?? '');
    _country = (contact?.country ?? '').trim().isEmpty
        ? '中国'
        : contact!.country;
    _province = contact?.province ?? '';
    _city = contact?.city ?? '';
    _district = contact?.district ?? '';
    _latitude = contact?.latitude;
    _longitude = contact?.longitude;
    _regionLatitude = contact?.regionLatitude;
    _regionLongitude = contact?.regionLongitude;
    _avatarPath = contact?.avatarPath ?? '';
    _qqFocus.addListener(_onQqFocusChanged);
  }

  @override
  void dispose() {
    _tipsDebounce?.cancel();
    _qqFocus.removeListener(_onQqFocusChanged);
    _qqFocus.dispose();
    _name.dispose();
    _nickname.dispose();
    _qq.dispose();
    _wechat.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _onQqFocusChanged() {
    if (!_qqFocus.hasFocus && mounted) {
      // 失焦时按当前 QQ 号刷新头像预览（网络图缓存按 URL 区分）。
      setState(() {});
    }
  }

  /// 中国（含港澳台）才使用省/市/区三级行政区；其他国家只填详细地址。
  bool get _isDomestic => _country.trim().startsWith('中国');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isEditing = widget.contact != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.contactsEdit : l10n.contactsAdd),
        actions: <Widget>[
          TextButton(onPressed: _save, child: Text(l10n.contactsSave)),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Center(
              child: _AvatarPicker(
                contact: _previewContact(),
                picked: _pickedAvatar,
                onTap: _pickAvatar,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.contactAvatarPick),
              ),
            ),
            const SizedBox(height: 8),
            _Field(controller: _name, label: l10n.contactName),
            _Field(controller: _nickname, label: l10n.contactNickname),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                controller: _qq,
                focusNode: _qqFocus,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.contactQq,
                  helperText: l10n.contactAvatarQq,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            _Field(controller: _wechat, label: l10n.contactWechat),
            _Field(
              controller: _phone,
              label: l10n.contactPhone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.contactLocation,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            _PickerField(
              label: l10n.contactCountry,
              value: _country,
              onTap: _pickCountry,
            ),
            // 境外地区高德没有省/市/区数据，直接填详细地址即可。
            if (_isDomestic) ...<Widget>[
              _PickerField(
                label: l10n.contactProvince,
                value: _province,
                onTap: _pickProvince,
              ),
              _PickerField(
                label: l10n.contactCity,
                value: _city,
                onTap: _province.isEmpty ? null : _pickCity,
              ),
              _PickerField(
                label: l10n.contactDistrict,
                value: _district,
                onTap: _city.isEmpty ? null : _pickDistrict,
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                controller: _address,
                decoration: InputDecoration(
                  labelText: l10n.contactAddress,
                  hintText: l10n.contactAddressHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: _tipsLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _onAddressChanged,
              ),
            ),
            if (_addressTips.isNotEmpty)
              _AddressTips(places: _addressTips, onSelected: _applyAddressTip),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l10n.contactsSave)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 头像预览用的临时对象：随输入实时反映 QQ / 名字。
  Contact _previewContact() {
    return Contact(
      id: widget.contact?.id ?? 'preview',
      name: _name.text.trim(),
      nickname: _nickname.text.trim(),
      qq: _qq.text.trim(),
      avatarPath: _avatarPath,
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 90,
      );
      if (picked == null) {
        return;
      }
      setState(() {
        _pickedAvatar = File(picked.path);
      });
    } on Exception {
      // 用户取消或平台不支持时保持原头像。
    }
  }

  Future<void> _pickCountry() async {
    final String? name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => _CountrySheet(initial: _country),
    );
    if (name == null || !mounted) {
      return;
    }
    final String value = name.trim();
    if (value.isEmpty || value == _country) {
      return;
    }
    setState(() {
      _country = value;
      // 换国家后，省市区的行政区划树不再适用，旧地址与坐标也一并清掉。
      _province = '';
      _city = '';
      _district = '';
      _regionLatitude = null;
      _regionLongitude = null;
      _resetDetailLocation();
    });
  }

  Future<void> _pickProvince() async {
    final AmapDistrict? picked = await _showDistrictSheet(
      label: AppLocalizations.of(context).contactProvince,
      keyword: _country,
    );
    if (picked == null || !mounted) {
      return;
    }
    final bool changed = picked.name != _province;
    setState(() {
      if (changed) {
        _province = picked.name;
        _city = '';
        _district = '';
        _resetDetailLocation();
      }
      // 已经有更细一级的行政区时，不让省中心覆盖它。
      if (changed || _city.isEmpty) {
        _applyRegionCenter(picked);
      }
    });
  }

  Future<void> _pickCity() async {
    final AmapDistrict? picked = await _showDistrictSheet(
      label: AppLocalizations.of(context).contactCity,
      keyword: _province,
    );
    if (picked == null || !mounted) {
      return;
    }
    final bool changed = picked.name != _city;
    setState(() {
      if (changed) {
        _city = picked.name;
        _district = '';
        _resetDetailLocation();
      }
      if (changed || _district.isEmpty) {
        _applyRegionCenter(picked);
      }
    });
  }

  Future<void> _pickDistrict() async {
    final AmapDistrict? picked = await _showDistrictSheet(
      label: AppLocalizations.of(context).contactDistrict,
      keyword: _city,
    );
    if (picked == null || !mounted) {
      return;
    }
    final bool changed = picked.name != _district;
    setState(() {
      if (changed) {
        _district = picked.name;
        _resetDetailLocation();
      }
      // 区县是最细一级，中心点始终以它为准。
      _applyRegionCenter(picked);
    });
  }

  /// 记下选中行政区的中心点；候选没有中心点时清空，避免沿用上一级坐标。
  void _applyRegionCenter(AmapDistrict district) {
    _regionLatitude = district.hasCenter ? district.latitude : null;
    _regionLongitude = district.hasCenter ? district.longitude : null;
  }

  /// 行政区变化后，旧的详细地点、候选与坐标都不再适用。
  void _resetDetailLocation() {
    _tipsDebounce?.cancel();
    _address.clear();
    _addressTips = <AmapPlace>[];
    _tipsLoading = false;
    _latitude = null;
    _longitude = null;
  }

  Future<AmapDistrict?> _showDistrictSheet({
    required String label,
    required String keyword,
  }) {
    return showModalBottomSheet<AmapDistrict>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          _DistrictSheet(label: label, keyword: keyword),
    );
  }

  void _onAddressChanged(String value) {
    _tipsDebounce?.cancel();
    // 手动改动地址后，之前候选的详细坐标失效；重新选中候选时才会记录。
    _latitude = null;
    _longitude = null;
    final String keyword = value.trim();
    if (keyword.isEmpty) {
      setState(() {
        _addressTips = <AmapPlace>[];
        _tipsLoading = false;
      });
      return;
    }
    if (!AmapService.isSupported) {
      return;
    }
    _tipsDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _tipsLoading = true);
      final List<AmapPlace> places = await AmapService.inputTips(
        keyword,
        city: _city.isNotEmpty ? _city : (_country == '中国' ? '' : _country),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _addressTips = places.take(8).toList();
        _tipsLoading = false;
      });
    });
  }

  void _applyAddressTip(AmapPlace place) {
    _tipsDebounce?.cancel();
    setState(() {
      _address.text = place.title;
      _latitude = place.latitude;
      _longitude = place.longitude;
      _addressTips = <AmapPlace>[];
    });
  }

  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = _name.text.trim();
    final String nickname = _nickname.text.trim();
    final String qq = _qq.text.trim();
    final String wechat = _wechat.text.trim();
    final String phone = _phone.text.trim();
    final String address = _address.text.trim();

    if (<String>[
      name,
      nickname,
      qq,
      wechat,
      phone,
    ].every((String value) => value.isEmpty)) {
      setState(() => _error = l10n.contactNeedOne);
      return;
    }

    final ContactStore store = ContactScope.of(context);
    final String id = widget.contact?.id ?? store.newId();
    String avatarPath = _avatarPath;
    final File? picked = _pickedAvatar;
    if (picked != null) {
      try {
        avatarPath = await store.saveAvatar(id, picked);
      } on Exception {
        avatarPath = _avatarPath;
      }
    }

    final Contact contact = Contact(
      id: id,
      name: name,
      nickname: nickname,
      qq: qq,
      wechat: wechat,
      phone: phone,
      country: _country,
      province: _province,
      city: _city,
      district: _district,
      address: address,
      latitude: _latitude,
      longitude: _longitude,
      regionLatitude: _regionLatitude,
      regionLongitude: _regionLongitude,
      avatarPath: avatarPath,
    );

    if (widget.contact == null) {
      store.add(contact);
    } else {
      store.update(contact);
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// 只读 / 点击选择的输入框外观。
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: Icon(
              enabled ? Icons.arrow_drop_down : Icons.lock_outline,
              size: enabled ? 24 : 18,
            ),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              color: value.isEmpty
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 行政区划候选底部弹层。
class _DistrictSheet extends StatefulWidget {
  const _DistrictSheet({required this.label, required this.keyword});

  final String label;
  final String keyword;

  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  late Future<List<AmapDistrict>> _future;

  @override
  void initState() {
    super.initState();
    _future = AmapService.districts(widget.keyword);
  }

  /// 高德没有候选（如海外地区）时，允许直接手填名称。
  Future<void> _promptManual() async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _ManualInputDialog(title: widget.label),
    );
    if (value == null || value.trim().isEmpty) {
      return;
    }
    if (mounted) {
      // 手填名称没有中心点，hasCenter 为 false，不会产生错误坐标。
      Navigator.of(context)
          .pop(AmapDistrict(name: value.trim(), adcode: '', level: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.locationPickTitle(widget.label),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AmapDistrict>>(
                future: _future,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<AmapDistrict>> snapshot,
                    ) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final List<AmapDistrict> items =
                          snapshot.data ?? <AmapDistrict>[];
                      return ListView(
                        children: <Widget>[
                          // 海外或高德无数据时，仍然允许手填，保证地址可用。
                          ListTile(
                            leading: const Icon(Icons.edit_outlined),
                            title: Text(l10n.contactManualInput),
                            onTap: _promptManual,
                          ),
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                AmapService.isSupported
                                    ? l10n.locationPickEmpty
                                    : l10n.locationPickUnsupported,
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            for (final AmapDistrict district in items)
                              ListTile(
                                title: Text(district.name),
                                onTap: () =>
                                    Navigator.of(context).pop(district),
                              ),
                        ],
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手填名称对话框：海外地区或高德没有候选时使用。
class _ManualInputDialog extends StatefulWidget {
  const _ManualInputDialog({required this.title});

  final String title;

  @override
  State<_ManualInputDialog> createState() => _ManualInputDialogState();
}

class _ManualInputDialogState extends State<_ManualInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.contactManualInputHint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.contactsCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.contactsSave)),
      ],
    );
  }
}

/// 国家 / 地区选择：常用列表 + 手填，覆盖中国大陆以外的联系人。
class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.initial});

  final String initial;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  static const List<String> _common = <String>[
    '中国',
    '中国香港',
    '中国澳门',
    '中国台湾',
    '美国',
    '日本',
    '韩国',
    '新加坡',
    '马来西亚',
    '泰国',
    '英国',
    '法国',
    '德国',
    '澳大利亚',
    '加拿大',
    '新西兰',
  ];

  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.locationPickTitle(l10n.contactCountry),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l10n.contactManualInputHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _submit,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      l10n.contactCountryCommon,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  for (final String name in _common)
                    ListTile(
                      title: Text(name),
                      onTap: () => Navigator.of(context).pop(name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 详细地址候选列表。
class _AddressTips extends StatelessWidget {
  const _AddressTips({required this.places, required this.onSelected});

  final List<AmapPlace> places;
  final ValueChanged<AmapPlace> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: places.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final AmapPlace place = places[index];
            return ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(
                place.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: place.snippet.isEmpty
                  ? null
                  : Text(
                      place.snippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onSelected(place),
            );
          },
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.contact,
    required this.picked,
    required this.onTap,
  });

  final Contact contact;
  final File? picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final File? local = picked;
    if (local != null) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: CircleAvatar(radius: 48, backgroundImage: FileImage(local)),
      );
    }
    final String avatarPath = contact.avatarPath;
    if (avatarPath.isNotEmpty) {
      final File file = File(avatarPath);
      if (file.existsSync()) {
        return InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: CircleAvatar(radius: 48, backgroundImage: FileImage(file)),
        );
      }
    }
    if (contact.qq.isNotEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: ContactAvatar(contact: contact, radius: 48),
      );
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: 48,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

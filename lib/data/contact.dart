/// 联系人数据模型。
///
/// 所有字段都可为空：新增时只要求至少填一项，展示时按
/// [displayName] 的优先级取一个可读名字。
class Contact {
  const Contact({
    required this.id,
    this.name = '',
    this.nickname = '',
    this.qq = '',
    this.wechat = '',
    this.phone = '',
    this.country = '中国',
    this.province = '',
    this.city = '',
    this.district = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.regionLatitude,
    this.regionLongitude,
    this.avatarPath = '',
  });

  /// 本地唯一标识，创建后不变。
  final String id;
  final String name;
  final String nickname;
  final String qq;
  final String wechat;
  final String phone;

  /// 所在地：国家 / 省 / 市 / 区县 / 详细地点。
  ///
  /// 省市区县来自高德行政区划候选，保证能在地图上定位；[address] 存详细地点，
  /// [latitude] / [longitude] 是选中详细地点候选时的坐标（可能为空）。
  ///
  /// [regionLatitude] / [regionLongitude] 是省 / 市 / 区县候选自带的中心点，
  /// 只精确到行政区时用它打点；旧数据首次进入地图时会自动补全。
  final String country;
  final String province;
  final String city;
  final String district;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? regionLatitude;
  final double? regionLongitude;

  /// 本地头像文件的绝对路径；为空时回退到 QQ 头像或首字母。
  final String avatarPath;

  /// 用于界面展示的名字：优先昵称，再退回姓名、QQ、微信、手机号。
  String get displayName {
    for (final String value in <String>[nickname, name, qq, wechat, phone]) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  /// 完整地点文本，例如「山东省淄博市临淄区 万丽花园」。
  String get locationText {
    final StringBuffer buffer = StringBuffer();
    final String countryText = country.trim();
    if (countryText.isNotEmpty && countryText != '中国') {
      buffer.write(countryText);
    }
    for (final String part in <String>[province, city, district]) {
      final String value = part.trim();
      if (value.isNotEmpty && !buffer.toString().contains(value)) {
        buffer.write(value);
      }
    }
    final String detail = address.trim();
    if (detail.isNotEmpty) {
      if (buffer.isEmpty) {
        buffer.write(detail);
      } else {
        buffer.write(' $detail');
      }
    }
    return buffer.toString().trim();
  }

  /// 至少填写了一项联系方式。
  bool get hasContent => displayName.isNotEmpty;

  /// 默认头像：QQ 号对应的高清头像地址。
  String? get qqAvatarUrl => qq.trim().isEmpty
      ? null
      : 'https://q.qlogo.cn/headimg_dl?dst_uin=${qq.trim()}&spec=640&img_type=jpg';

  /// 详细地址坐标是否成对可用。
  bool get hasDetailCoordinates => latitude != null && longitude != null;

  /// 行政区中心坐标是否成对可用。
  bool get hasRegionCoordinates =>
      regionLatitude != null && regionLongitude != null;

  /// 地图能否打点：详细地址优先，只精确到省/市/区时退回行政区中心。
  bool get isLocatable => hasDetailCoordinates || hasRegionCoordinates;

  /// 地图打点用的纬度：详细地址坐标优先，否则用行政区中心。
  double? get mapLatitude => hasDetailCoordinates
      ? latitude
      : (hasRegionCoordinates ? regionLatitude : null);

  /// 地图打点用的经度：详细地址坐标优先，否则用行政区中心。
  double? get mapLongitude => hasDetailCoordinates
      ? longitude
      : (hasRegionCoordinates ? regionLongitude : null);

  Contact copyWith({
    String? name,
    String? nickname,
    String? qq,
    String? wechat,
    String? phone,
    String? country,
    String? province,
    String? city,
    String? district,
    String? address,
    double? latitude,
    double? longitude,
    double? regionLatitude,
    double? regionLongitude,
    String? avatarPath,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      qq: qq ?? this.qq,
      wechat: wechat ?? this.wechat,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      regionLatitude: regionLatitude ?? this.regionLatitude,
      regionLongitude: regionLongitude ?? this.regionLongitude,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'nickname': nickname,
    'qq': qq,
    'wechat': wechat,
    'phone': phone,
    'country': country,
    'province': province,
    'city': city,
    'district': district,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'regionLatitude': regionLatitude,
    'regionLongitude': regionLongitude,
    'avatarPath': avatarPath,
  };

  /// 解析单条记录；缺少 id 的脏数据返回 null。
  ///
  /// 旧版本只有 `location` 字段，读取时整体迁移到 [address]。
  static Contact? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final Object? id = json['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    String read(String key) => switch (json[key]) {
      final String value => value,
      final Object value => '$value',
      _ => '',
    };
    double? readDouble(String key) => switch (json[key]) {
      final num value => value.toDouble(),
      final String value => double.tryParse(value),
      _ => null,
    };
    final String legacyLocation = read('location');
    final String address = read('address');
    return Contact(
      id: id,
      name: read('name'),
      nickname: read('nickname'),
      qq: read('qq'),
      wechat: read('wechat'),
      phone: read('phone'),
      country: read('country').isEmpty ? '中国' : read('country'),
      province: read('province'),
      city: read('city'),
      district: read('district'),
      address: address.isEmpty ? legacyLocation : address,
      latitude: readDouble('latitude'),
      longitude: readDouble('longitude'),
      regionLatitude: readDouble('regionLatitude'),
      regionLongitude: readDouble('regionLongitude'),
      avatarPath: read('avatarPath'),
    );
  }

  @override
  bool operator ==(Object other) => other is Contact && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

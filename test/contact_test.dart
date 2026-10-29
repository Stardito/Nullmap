import 'package:flutter_test/flutter_test.dart';
import 'package:nullmap/data/contact.dart';

void main() {
  test('详细地址坐标优先于行政区中心', () {
    const Contact contact = Contact(
      id: 'a',
      latitude: 36.85,
      longitude: 118.05,
      regionLatitude: 36.80,
      regionLongitude: 118.00,
    );

    expect(contact.hasDetailCoordinates, isTrue);
    expect(contact.isLocatable, isTrue);
    expect(contact.mapLatitude, 36.85);
    expect(contact.mapLongitude, 118.05);
  });

  test('只精确到行政区时用中心点打点', () {
    const Contact contact = Contact(
      id: 'b',
      province: '山东省',
      city: '淄博市',
      district: '临淄区',
      regionLatitude: 36.82,
      regionLongitude: 118.31,
    );

    expect(contact.hasDetailCoordinates, isFalse);
    expect(contact.hasRegionCoordinates, isTrue);
    expect(contact.isLocatable, isTrue);
    expect(contact.mapLatitude, 36.82);
    expect(contact.mapLongitude, 118.31);
  });

  test('详细坐标不成对时退回行政区中心', () {
    const Contact contact = Contact(
      id: 'c',
      latitude: 36.85,
      regionLatitude: 36.80,
      regionLongitude: 118.00,
    );

    expect(contact.hasDetailCoordinates, isFalse);
    expect(contact.mapLatitude, 36.80);
    expect(contact.mapLongitude, 118.00);
  });

  test('没有行政区中心时不可定位', () {
    const Contact contact = Contact(id: 'd', province: '山东省');

    expect(contact.hasRegionCoordinates, isFalse);
    expect(contact.isLocatable, isFalse);
    expect(contact.mapLatitude, isNull);
    expect(contact.mapLongitude, isNull);
  });

  test('JSON 往返保留行政区中心，旧数据缺字段时为 null', () {
    const Contact contact = Contact(
      id: 'e',
      city: '淄博市',
      regionLatitude: 36.81,
      regionLongitude: 118.06,
    );
    final Contact? restored = Contact.fromJson(contact.toJson());

    expect(restored, isNotNull);
    expect(restored!.regionLatitude, 36.81);
    expect(restored.regionLongitude, 118.06);
    expect(restored.isLocatable, isTrue);

    final Contact? legacy = Contact.fromJson(<String, Object?>{
      'id': 'f',
      'province': '山东省',
    });
    expect(legacy, isNotNull);
    expect(legacy!.regionLatitude, isNull);
    expect(legacy.regionLongitude, isNull);
    expect(legacy.isLocatable, isFalse);
  });
}

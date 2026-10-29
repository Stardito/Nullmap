import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../data/contact.dart';

/// 联系人头像：本地图片 > QQ 头像 > 首字母。
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.radius = 24});

  final Contact contact;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String localPath = contact.avatarPath;
    if (localPath.isNotEmpty) {
      final File file = File(localPath);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(file),
        );
      }
    }

    final String? qqAvatar = contact.qqAvatarUrl;
    if (qqAvatar != null) {
      return ClipOval(
        child: Image.network(
          qqAvatar,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initials(scheme),
        ),
      );
    }

    return _initials(scheme);
  }

  Widget _initials(ColorScheme scheme) {
    final String name = contact.displayName;
    final String initial = name.isEmpty
        ? ''
        : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: initial.isEmpty
          ? Icon(Icons.person_outline, size: radius, color: scheme.onPrimaryContainer)
          : Text(
              initial,
              style: TextStyle(fontSize: radius * 0.9),
            ),
    );
  }
}

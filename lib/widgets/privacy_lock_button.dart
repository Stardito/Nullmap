import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../services/privacy.dart';

/// 右上角的「上锁 / 解锁」按钮：只在开启「隐藏敏感信息」时出现。
///
/// 解锁状态是会话级的：点一下解锁后，列表、详情、地图一直用明文，
/// 直到用户手动上锁或应用被系统清掉。
class PrivacyLockButton extends StatelessWidget {
  const PrivacyLockButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = AppSettingsScope.of(context);
    if (!settings.privacyLock) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: PrivacyGate.instance,
      builder: (BuildContext context, Widget? child) {
        final bool unlocked = PrivacyGate.instance.unlocked;
        return IconButton(
          tooltip: unlocked ? l10n.privacyLockNow : l10n.privacyUnlock,
          icon: Icon(unlocked ? Icons.lock_open : Icons.lock_outline),
          onPressed: () async {
            if (unlocked) {
              PrivacyGate.instance.lock();
              return;
            }
            if (!await PrivacyGate.instance.requestUnlock(
              context,
              reason: l10n.privacyUnlockReason,
              noLockMessage: l10n.privacyNoDeviceLock,
              failedMessage: l10n.privacyAuthFailed,
            )) {
              return;
            }
          },
        );
      },
    );
  }
}

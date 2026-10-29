import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';
import '../data/contact_store.dart';
import '../l10n/app_localizations.dart';
import '../services/backup.dart';
import '../services/privacy.dart';

/// 隐私与安全：敏感信息隐藏、地图验证锁定、备份与恢复。
///
/// 开关类操作同样要过屏幕锁：否则任何人都能先把隐藏关掉再看数据。
class SettingsPrivacyPage extends StatelessWidget {
  const SettingsPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = AppSettingsScope.of(context);
    final ContactStore store = ContactScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacy)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: Text(l10n.privacyLock),
                  subtitle: Text(l10n.privacyLockSubtitle),
                  value: settings.privacyLock,
                  onChanged: (bool value) =>
                      _toggleLock(context, settings, value),
                ),
                if (settings.privacyLock) ...<Widget>[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.blur_on),
                    title: Text(l10n.privacyLockMap),
                    subtitle: Text(l10n.privacyLockMapSubtitle),
                    value: settings.privacyLockMap,
                    onChanged: (bool value) =>
                        _toggleMapLock(context, settings, value),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(l10n.privacyBackup),
                  subtitle: Text(l10n.privacyBackupSubtitle),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(l10n.privacyExport),
                  subtitle: Text(
                    l10n.privacyExportSubtitle(store.contacts.length),
                  ),
                  onTap: () => _export(context, settings, store),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(l10n.privacyImport),
                  subtitle: Text(l10n.privacyImportSubtitle),
                  onTap: () => _import(context, settings, store),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l10n.privacyLockHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 开关「隐藏敏感信息」：先验证，再落设置。
  Future<void> _toggleLock(
    BuildContext context,
    AppSettings settings,
    bool value,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool ok = await _verify(context, l10n.privacyToggleReason);
    if (!ok) {
      return;
    }
    // 刚验证过，本次会话直接算已解锁，省得用户马上再验一次。
    PrivacyGate.instance.unlock();
    await settings.setPrivacyLock(value);
    if (!value) {
      await settings.setPrivacyLockMap(false);
    }
  }

  Future<void> _toggleMapLock(
    BuildContext context,
    AppSettings settings,
    bool value,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!PrivacyGate.instance.unlocked) {
      final bool ok = await _verify(context, l10n.privacyToggleReason);
      if (!ok) {
        return;
      }
      PrivacyGate.instance.unlock();
    }
    await settings.setPrivacyLockMap(value);
  }

  Future<void> _export(
    BuildContext context,
    AppSettings settings,
    ContactStore store,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (settings.privacyLock &&
        !await _verify(context, l10n.privacyBackupReason)) {
      return;
    }
    final BackupResult result = await BackupService.export(
      store: store,
      settings: settings,
    );
    if (!context.mounted) {
      return;
    }
    _toast(
      context,
      result.ok
          ? l10n.privacyExportDone(result.count, result.path ?? '')
          : _errorText(l10n, result.error),
    );
  }

  Future<void> _import(
    BuildContext context,
    AppSettings settings,
    ContactStore store,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.privacyImportConfirmTitle),
        content: Text(l10n.privacyImportConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.contactsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.privacyImport),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    if (settings.privacyLock &&
        !await _verify(context, l10n.privacyBackupReason)) {
      return;
    }
    final BackupResult result = await BackupService.restore(
      store: store,
      settings: settings,
    );
    if (!context.mounted) {
      return;
    }
    if (result.ok) {
      // 恢复后立刻上锁：导入文件可能来自别人，别让敏感信息直接敞开。
      PrivacyGate.instance.lock();
    }
    _toast(
      context,
      result.ok
          ? l10n.privacyImportDone(result.count)
          : _errorText(l10n, result.error),
    );
  }

  Future<bool> _verify(BuildContext context, String reason) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return requireDeviceUnlock(
      context,
      reason: reason,
      noLockMessage: l10n.privacyNoDeviceLock,
      failedMessage: l10n.privacyAuthFailed,
    );
  }

  String _errorText(AppLocalizations l10n, String? code) => switch (code) {
    'unsupported' => l10n.privacyBackupUnsupported,
    'format' => l10n.privacyImportInvalid,
    'empty' => l10n.privacyImportCanceled,
    _ => l10n.privacyBackupFailed,
  };

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

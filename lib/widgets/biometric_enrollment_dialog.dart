import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Modal dialog offering explicit parent enrollment in biometric authentication.
class BiometricEnrollmentDialog {
  /// Prompts the authenticated parent to enable biometric login if supported and not yet enabled.
  static Future<void> maybePrompt(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;

    await auth.checkBiometricSupport();
    if (!auth.isBiometricSupported || auth.isBiometricEnabled) return;
    if (!context.mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF1E3A8A),
              child: Icon(Icons.fingerprint, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đăng nhập Sinh trắc học',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'Thiết bị của bạn hỗ trợ xác thực sinh trắc học (vân tay, nhận diện khuôn mặt). '
          'Bạn có muốn kích hoạt để đăng nhập nhanh vào Chế độ Phụ huynh trong các lần sau mà không cần nhập lại mật khẩu không?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.fingerprint, size: 18),
            label: const Text('Kích hoạt ngay'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (enable == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final enrolled = await auth.enableBiometricLogin();
      if (enrolled) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã kích hoạt đăng nhập bằng sinh trắc học thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Displays a settings dialog for the parent to view or toggle biometric login on/off.
  static void showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _BiometricSettingsDialog(),
    );
  }
}

class _BiometricSettingsDialog extends StatefulWidget {
  const _BiometricSettingsDialog();

  @override
  State<_BiometricSettingsDialog> createState() => _BiometricSettingsDialogState();
}

class _BiometricSettingsDialogState extends State<_BiometricSettingsDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.security, color: Color(0xFF1E3A8A)),
          SizedBox(width: 10),
          Text('Bảo mật & Sinh trắc học', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null) ...[
            Text('Tài khoản: ${user.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(user.email, style: theme.textTheme.bodySmall),
            const Divider(height: 24),
          ],
          if (!auth.isBiometricSupported) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thiết bị chưa cài đặt hoặc không hỗ trợ sinh trắc học.',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Đăng nhập bằng sinh trắc học',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                auth.isBiometricEnabled
                    ? 'Đang bật (vân tay / khuôn mặt)'
                    : 'Đang tắt - yêu cầu mật khẩu & OTP',
                style: const TextStyle(fontSize: 12),
              ),
              value: auth.isBiometricEnabled,
              onChanged: _isProcessing
                  ? null
                  : (enable) async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isProcessing = true);
                      if (enable) {
                        final success = await auth.enableBiometricLogin();
                        if (mounted && success) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Đã bật đăng nhập bằng sinh trắc học.'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        await auth.disableBiometricLogin();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Đã tắt đăng nhập bằng sinh trắc học.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      if (mounted) {
                        setState(() => _isProcessing = false);
                      }
                    },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../constants/api_constants.dart';
import '../../models/device_mode_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_mode_provider.dart';
import '../admin_home_screen.dart';
import '../login_screen.dart';
import '../parent_home_screen.dart';
import 'child_enrollment_screen.dart';

/// Modal dialog requiring Parent Authorization before switching to Parent Mode or Unlinking.
class ChildModeUnlockDialog extends StatefulWidget {
  final String targetMode; // 'ParentMode' or 'Unlink'

  const ChildModeUnlockDialog({
    super.key,
    required this.targetMode,
  });

  @override
  State<ChildModeUnlockDialog> createState() => _ChildModeUnlockDialogState();
}

class _ChildModeUnlockDialogState extends State<ChildModeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Remote Request State
  DeviceModeRequestModel? _currentRequest;
  bool _isSendingRequest = false;
  bool _isCheckingStatus = false;
  String? _remoteErrorMessage;
  Timer? _statusPollTimer;

  // Direct Unlock State
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isDirectUnlocking = false;
  bool _obscurePassword = true;
  String? _directErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingPendingRequest();
    });
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPendingRequest() async {
    final provider = context.read<ChildModeProvider>();
    final pending = await provider.checkPendingModeRequestStatus();
    if (mounted && pending != null && pending.isPending) {
      setState(() {
        _currentRequest = pending;
      });
      _startStatusPolling();
    }
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkStatusSilently();
    });
  }

  Future<void> _checkStatusSilently() async {
    if (!mounted || _currentRequest == null) return;
    final provider = context.read<ChildModeProvider>();
    final updated = await provider.checkPendingModeRequestStatus();
    if (!mounted || updated == null) return;

    setState(() {
      _currentRequest = updated;
    });

    if (updated.isApproved) {
      _statusPollTimer?.cancel();
      await _onApproved(updated);
    } else if (updated.isRejected || updated.isExpired) {
      _statusPollTimer?.cancel();
    }
  }

  Future<void> _sendRemoteRequest() async {
    setState(() {
      _isSendingRequest = true;
      _remoteErrorMessage = null;
    });

    final provider = context.read<ChildModeProvider>();
    final req = await provider.requestModeChange(
      targetMode: widget.targetMode,
      reason: widget.targetMode == 'Unlink'
          ? 'Yêu cầu hủy liên kết thiết bị từ trẻ'
          : 'Yêu cầu chuyển sang Chế độ Phụ huynh',
    );

    if (!mounted) return;

    if (req != null) {
      setState(() {
        _currentRequest = req;
        _isSendingRequest = false;
      });
      _startStatusPolling();
    } else {
      setState(() {
        _remoteErrorMessage = provider.modeRequestError ?? 'Gửi yêu cầu thất bại.';
        _isSendingRequest = false;
      });
    }
  }

  Future<void> _checkStatusManually() async {
    setState(() {
      _isCheckingStatus = true;
      _remoteErrorMessage = null;
    });

    final provider = context.read<ChildModeProvider>();
    final updated = await provider.checkPendingModeRequestStatus();

    if (!mounted) return;
    setState(() {
      _isCheckingStatus = false;
      if (updated != null) {
        _currentRequest = updated;
      }
    });

    if (updated != null && updated.isApproved) {
      _statusPollTimer?.cancel();
      await _onApproved(updated);
    }
  }

  Future<void> _onApproved(DeviceModeRequestModel approvedRequest) async {
    final token = approvedRequest.approvalToken;
    if (token == null || token.isEmpty) return;

    final provider = context.read<ChildModeProvider>();
    final executed = await provider.executeApprovedModeChange(
      requestId: approvedRequest.id,
      approvalToken: token,
    );

    if (!mounted) return;

    if (executed) {
      Navigator.of(context).pop();
      await _completeModeTransition();
    } else {
      setState(() {
        _remoteErrorMessage = provider.modeRequestError ?? 'Lỗi khi kích hoạt chế độ mới.';
      });
    }
  }

  Future<void> _directUnlock() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _directErrorMessage = 'Vui lòng nhập đầy đủ Email và Mật khẩu phụ huynh.';
      });
      return;
    }

    setState(() {
      _isDirectUnlocking = true;
      _directErrorMessage = null;
    });

    final provider = context.read<ChildModeProvider>();
    final success = await provider.directParentUnlock(
      email: email,
      password: password,
      targetMode: widget.targetMode,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      await _completeModeTransition();
    } else {
      setState(() {
        _directErrorMessage = provider.modeRequestError ?? 'Xác thực thất bại. Vui lòng thử lại.';
        _isDirectUnlocking = false;
      });
    }
  }

  Future<void> _completeModeTransition() async {
    const secureStorage = FlutterSecureStorage();

    if (widget.targetMode == 'Unlink') {
      await context.read<ChildModeProvider>().clearChildSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChildEnrollmentScreen()),
      );
    } else {
      // Switch to Parent Mode
      await secureStorage.write(key: ApiConstants.appModeStorageKey, value: 'parent');

      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      await authProvider.checkSession();

      if (!mounted) return;
      if (authProvider.isAuthenticated) {
        final user = authProvider.user!;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => user.isAdmin ? const AdminHomeScreen() : const ParentHomeScreen(),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlink = widget.targetMode == 'Unlink';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isUnlink ? Colors.red.shade100 : theme.colorScheme.primaryContainer,
            child: Icon(
              isUnlink ? Icons.link_off : Icons.lock_outline,
              size: 20,
              color: isUnlink ? Colors.red.shade700 : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUnlink ? 'Xác nhận hủy liên kết' : 'Yêu cầu quyền Phụ huynh',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isUnlink
                      ? 'Cần sự đồng ý của cha mẹ để hủy'
                      : 'Cần sự đồng ý của cha mẹ để đổi chế độ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(
                  icon: Icon(Icons.send_to_mobile, size: 18),
                  text: 'Yêu cầu từ xa',
                ),
                Tab(
                  icon: Icon(Icons.password, size: 18),
                  text: 'Nhập mật khẩu',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRemoteRequestTab(theme),
                  _buildDirectUnlockTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _statusPollTimer?.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('Hủy bỏ'),
        ),
      ],
    );
  }

  Widget _buildRemoteRequestTab(ThemeData theme) {
    if (_currentRequest != null) {
      final req = _currentRequest!;

      Color statusColor;
      IconData statusIcon;
      if (req.isApproved) {
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
      } else if (req.isRejected) {
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel;
      } else if (req.isExpired) {
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.timer_off;
      } else {
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.hourglass_top;
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        req.statusLabelVi,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    req.isPending
                        ? 'Yêu cầu đang hiển thị trên ứng dụng của cha mẹ. Thiết bị sẽ tự động mở khóa ngay khi cha mẹ nhấn Phê duyệt.'
                        : req.isApproved
                            ? 'Cha mẹ đã đồng ý! Đang hoàn tất chuyển đổi...'
                            : req.isRejected
                                ? 'Cha mẹ đã từ chối yêu cầu chuyển chế độ.'
                                : 'Yêu cầu đã quá thời gian chờ (15 phút).',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (req.isPending) ...[
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: _isCheckingStatus
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 16),
                label: const Text('Kiểm tra phản hồi ngay'),
                onPressed: _isCheckingStatus ? null : _checkStatusManually,
              ),
            ] else ...[
              FilledButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Gửi lại yêu cầu mới'),
                onPressed: _sendRemoteRequest,
              ),
            ],
            if (_remoteErrorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _remoteErrorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.mark_email_unread_outlined, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            'Gửi thông báo phê duyệt tới ứng dụng của cha mẹ. Cha mẹ có thể phê duyệt từ xa ở bất cứ đâu.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _isSendingRequest
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Gửi yêu cầu phê duyệt'),
            onPressed: _isSendingRequest ? null : _sendRemoteRequest,
          ),
          if (_remoteErrorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _remoteErrorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectUnlockTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dành cho trường hợp cha mẹ đang trực tiếp cầm máy của con:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email phụ huynh',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu phụ huynh',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          if (_directErrorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _directErrorMessage!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: _isDirectUnlocking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.lock_open),
            label: const Text('Xác nhận & Mở khóa'),
            onPressed: _isDirectUnlocking ? null : _directUnlock,
          ),
        ],
      ),
    );
  }
}


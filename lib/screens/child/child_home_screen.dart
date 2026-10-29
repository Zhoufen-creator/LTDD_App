import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/monitoring_rule_model.dart';
import '../../providers/child_mode_provider.dart';
import 'child_enrollment_screen.dart';
import 'child_mode_unlock_dialog.dart';

/// Minimalist Child Home Dashboard.
/// Displays linked child profile, device enrollment status, active rules,
/// real-time usage permissions, offline queue, and parental rule enforcement alerts.
class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChildModeProvider>();
      if (provider.rules.isEmpty && !provider.isLoadingRules) {
        provider.fetchMyRules();
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$h:$m:$s - $day/$month/$year';
  }

  Future<void> _confirmUnlink() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChildModeUnlockDialog(targetMode: 'Unlink'),
    );
  }

  Future<void> _switchToParentMode() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChildModeUnlockDialog(targetMode: 'ParentMode'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ChildModeProvider>();
    final rules = provider.rules;
    final childName = provider.childName ?? 'Trẻ em';
    final deviceId = provider.deviceId;
    final lastSync = provider.lastSyncTime;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chế độ Trẻ Em'),
        actions: [
          IconButton(
            tooltip: 'Làm mới quy tắc',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoadingRules ? null : () => provider.fetchMyRules(),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'unlink') {
                _confirmUnlink();
              } else if (val == 'switch_mode') {
                _switchToParentMode();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'switch_mode',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    SizedBox(width: 8),
                    Text('Chuyển sang Chế độ Phụ huynh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unlink',
                child: Row(
                  children: [
                    Icon(Icons.link_off, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hủy liên kết thiết bị', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchMyRules(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: provider.isTokenRevoked
                      ? theme.colorScheme.error.withValues(alpha: 0.5)
                      : theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: provider.isTokenRevoked
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.primaryContainer,
                          child: Icon(
                            provider.isTokenRevoked ? Icons.warning : Icons.check_circle,
                            color: provider.isTokenRevoked
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                childName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.isTokenRevoked
                                    ? 'Phiên hoạt động bị từ chối / hết hạn'
                                    : 'Thiết bị đã liên kết • ID: #${deviceId ?? "?"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: provider.isTokenRevoked
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: provider.isTokenRevoked ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!provider.isTokenRevoked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: provider.batteryStatus?.isLowBattery == true
                                  ? Colors.red.shade50
                                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: provider.batteryStatus?.isLowBattery == true
                                    ? Colors.red.shade300
                                    : theme.colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  provider.batteryStatus?.isCharging == true
                                      ? Icons.battery_charging_full
                                      : (provider.batteryStatus?.isLowBattery == true
                                          ? Icons.battery_alert
                                          : Icons.battery_std),
                                  size: 16,
                                  color: provider.batteryStatus?.isLowBattery == true
                                      ? Colors.red.shade800
                                      : theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${provider.batteryStatus?.percentage ?? 100}%${provider.batteryStatus?.isCharging == true ? " ⚡" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: provider.batteryStatus?.isLowBattery == true
                                        ? Colors.red.shade900
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (provider.batteryStatus?.isLowBattery == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Cảnh báo: Pin thiết bị dưới 20% (${provider.batteryStatus?.percentage}%) - vui lòng cắm sạc!',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              provider.isAutoSyncRunning ? Icons.sync : Icons.sync_disabled,
                              size: 16,
                              color: provider.isAutoSyncRunning ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              provider.isAutoSyncRunning
                                  ? 'Tự động giám sát: Đang chạy'
                                  : (lastSync != null ? 'Đồng bộ: ${_formatDateTime(lastSync)}' : 'Chưa đồng bộ'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: provider.isAutoSyncRunning ? Colors.green.shade800 : theme.colorScheme.onSurfaceVariant,
                                fontWeight: provider.isAutoSyncRunning ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (provider.isLoadingRules)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Rule Violation Alert
            if (provider.lastViolation != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade400, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.block, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phát hiện vi phạm quy tắc!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.lastViolation!.violationReason ?? 'Ứng dụng đã bị chặn theo quy tắc của cha mẹ.',
                            style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => provider.clearViolation(),
                      tooltip: 'Đóng cảnh báo',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Android 13 Permission Warning Cards (Usage Access & Overlay)
            if (!provider.hasUsagePermission) ...[
              Card(
                elevation: 0,
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade400),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cần quyền Truy cập dữ liệu sử dụng',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Để hệ thống ghi nhận thời gian sử dụng ứng dụng và thực thi quy tắc giới hạn theo yêu cầu của cha mẹ, vui lòng bật quyền trong Cài đặt Android.',
                        style: TextStyle(fontSize: 12.5, color: Colors.brown.shade800),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Mở Cài đặt cấp quyền'),
                          onPressed: () => provider.requestUsageAccess(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (!provider.hasOverlayPermission) ...[
              Card(
                elevation: 0,
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.layers_outlined, color: Colors.orange.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cần quyền Hiển thị trên ứng dụng khác',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Quyền này giúp ứng dụng hiển thị màn hình khóa hoặc cảnh báo khi con sử dụng ứng dụng bị chặn hoặc hết giờ.',
                        style: TextStyle(fontSize: 12.5, color: Colors.brown.shade800),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Cấp quyền hiển thị cảnh báo'),
                          onPressed: () => provider.requestOverlayPermission(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Offline Sync Queue status indicator
            if (provider.pendingOfflineEventsCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chờ đồng bộ: ${provider.pendingOfflineEventsCount} sự kiện hoạt động offline',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Token Revocation or Error Alert
            if (provider.isTokenRevoked) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link_off, color: theme.colorScheme.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Thiết bị đã bị hủy liên kết hoặc mã xác thực hết hạn.',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const ChildEnrollmentScreen()),
                        );
                      },
                      child: const Text('Ghép nối lại thiết bị'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else if (provider.rulesError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.rulesError!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                    TextButton(
                      onPressed: () => provider.fetchMyRules(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Location Sync Card
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.my_location,
                            color: theme.colorScheme.onSecondaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chia sẻ vị trí GPS',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Cập nhật tọa độ thiết bị để phụ huynh theo dõi',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (provider.lastLocation != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.place, size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tọa độ: ${provider.lastLocation!.coordinatesFormatted}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Cập nhật: ${_formatDateTime(provider.lastLocation!.recordedAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (provider.locationError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.locationError!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (provider.locationError!.contains('Cài đặt'))
                              TextButton(
                                onPressed: () => provider.openAppSettingsScreen(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Mở Cài đặt', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: provider.isUpdatingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(provider.isUpdatingLocation
                            ? 'Đang lấy vị trí GPS...'
                            : 'Cập nhật vị trí'),
                        onPressed: (provider.isUpdatingLocation || provider.isTokenRevoked)
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final success = await provider.updateAndSendLocation();
                                if (!mounted) return;
                                if (success && provider.locationSuccessMessage != null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(provider.locationSuccessMessage!),
                                      backgroundColor: Colors.green.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section Header: Monitoring Rules
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quy tắc giám sát đang áp dụng',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text('${rules.length} quy tắc'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Rules List
            if (provider.isLoadingRules && rules.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (rules.isEmpty) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 56,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Chưa có quy tắc giám sát nào',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Phụ huynh chưa thiết lập quy tắc nào cho bạn. Bạn có thể sử dụng thiết bị bình thường.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              for (final rule in rules) _buildRuleCard(rule, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(MonitoringRuleModel rule, ThemeData theme) {
    String detailText = '';
    if (rule.appBlockConfig != null) {
      detailText = 'Ứng dụng: ${rule.appBlockConfig!.appName} (${rule.appBlockConfig!.targetPackage})';
    } else if (rule.timeLimitConfig != null) {
      detailText = 'Giới hạn: ${rule.timeLimitConfig!.dailyLimitMinutes} phút / ngày (${rule.timeLimitConfig!.appName})';
    } else if (rule.bedTimeConfig != null) {
      detailText = 'Khung giờ nghỉ ngơi: ${rule.bedTimeConfig!.bedtimeStart} - ${rule.bedTimeConfig!.bedtimeEnd}';
    } else if (rule.ruleType == 'WebFilter' || rule.ruleType == 'ContentFilter') {
      detailText = 'Lọc nội dung duyệt web (Yêu cầu cấu hình VPN hệ thống)';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: rule.isEnabled
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rule.isEnabled
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            _getRuleIcon(rule.ruleType),
            color: rule.isEnabled
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.outline,
          ),
        ),
        title: Text(
          rule.ruleName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: rule.isEnabled ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rule.description != null && rule.description!.isNotEmpty)
              Text(rule.description!),
            if (detailText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                detailText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Loại: ${rule.ruleType} • Phiên bản: v${rule.version}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: rule.syncStatus == 'Active'
                        ? Colors.green.shade50
                        : (rule.syncStatus == 'PermissionDenied'
                            ? Colors.red.shade50
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: rule.syncStatus == 'Active'
                          ? Colors.green.shade300
                          : (rule.syncStatus == 'PermissionDenied'
                              ? Colors.red.shade300
                              : Colors.grey.shade400),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    rule.syncStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: rule.syncStatus == 'Active'
                          ? Colors.green.shade800
                          : (rule.syncStatus == 'PermissionDenied'
                              ? Colors.red.shade800
                              : Colors.grey.shade800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: rule.isEnabled
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            rule.isEnabled ? 'Đang bật' : 'Tạm tắt',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: rule.isEnabled ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getRuleIcon(String ruleType) {
    switch (ruleType.toLowerCase()) {
      case 'appblock':
      case 'applimit':
      case 'app':
        return Icons.apps;
      case 'timelimit':
        return Icons.timer;
      case 'bedtime':
      case 'time':
        return Icons.bedtime;
      case 'website':
      case 'webfilter':
        return Icons.web;
      case 'contentfilter':
        return Icons.filter_list;
      case 'location':
        return Icons.location_on;
      default:
        return Icons.rule;
    }
  }
}

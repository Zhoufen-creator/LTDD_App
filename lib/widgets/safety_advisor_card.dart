import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/child_model.dart';
import '../models/safety_advisor_model.dart';
import '../screens/children/child_location_dialog.dart';
import '../screens/children/pairing_qr_dialog.dart';
import '../services/api_service.dart';
import '../services/safety_advisor_service.dart';

/// Reusable card component displaying Smart Safety Advisor evaluation,
/// statuses, actionable warnings, and remedy workflows for a specific child.
class SafetyAdvisorCard extends StatefulWidget {
  final ChildModel child;
  final ISafetyAdvisorService? safetyAdvisorOverride;
  final VoidCallback? onRefreshRequested;

  const SafetyAdvisorCard({
    super.key,
    required this.child,
    this.safetyAdvisorOverride,
    this.onRefreshRequested,
  });

  @override
  State<SafetyAdvisorCard> createState() => SafetyAdvisorCardState();
}

class SafetyAdvisorCardState extends State<SafetyAdvisorCard> {
  SafetyAdvisorModel? _advisorData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadAdvisorData();
  }

  @override
  void didUpdateWidget(covariant SafetyAdvisorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.id != widget.child.id) {
      loadAdvisorData();
    }
  }

  /// Public reload method accessible by parent refresh handlers.
  Future<void> loadAdvisorData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    ISafetyAdvisorService? service = widget.safetyAdvisorOverride;
    if (service == null) {
      try {
        service = context.read<SafetyAdvisorService>();
      } catch (_) {
        service = SafetyAdvisorService();
      }
    }

    try {
      final data = await service.getSafetyAdvisor(childId: widget.child.id);
      if (!mounted) return;
      setState(() {
        _advisorData = data;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể phân tích an toàn: $e';
      });
    }
  }

  void _handleAction(SafetyWarningModel warning) {
    if (warning.canRefreshLocation || warning.isStaleLocation || warning.isNoLocation) {
      showDialog(
        context: context,
        builder: (_) => ChildLocationDialog(child: widget.child),
      ).then((_) {
        // Refresh advisor when returning from location dialog
        loadAdvisorData(isSilent: true);
      });
    } else if (warning.canPairDevice || warning.isNoDevice) {
      showDialog(
        context: context,
        builder: (_) => PairingQrDialog(child: widget.child),
      ).then((_) {
        loadAdvisorData(isSilent: true);
      });
    } else if (warning.canChargeDevice || warning.canContactChild) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(warning.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(warning.message),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning.suggestedAction,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(theme),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 8, top: 10, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: _advisorData?.statusColor ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cố vấn An toàn',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_advisorData != null && !_isLoading)
                  _buildStatusPill(_advisorData!),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Đánh giá lại',
                  onPressed: () => loadAdvisorData(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildBody(theme),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(ThemeData theme) {
    if (_advisorData == null) {
      return theme.colorScheme.outlineVariant.withValues(alpha: 0.4);
    }
    if (_advisorData!.isWarning) {
      return Colors.red.shade300;
    }
    if (_advisorData!.isNeedsAttention) {
      return Colors.amber.shade400;
    }
    if (_advisorData!.isSafe) {
      return Colors.green.shade300;
    }
    return theme.colorScheme.outlineVariant.withValues(alpha: 0.4);
  }

  Widget _buildStatusPill(SafetyAdvisorModel data) {
    final color = data.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.statusIcon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            data.statusBadgeLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Đang phân tích dữ liệu an toàn...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => loadAdvisorData(),
            child: const Text('Thử lại', style: TextStyle(fontSize: 12)),
          ),
        ],
      );
    }

    final data = _advisorData;
    if (data == null) {
      return const SizedBox.shrink();
    }

    // State 1: Insufficient Data
    if (data.isInsufficientData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline, size: 18, color: Colors.blueGrey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.statusMessage.isNotEmpty
                      ? data.statusMessage
                      : 'Chưa có đủ dữ liệu giám sát từ thiết bị của trẻ.',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800),
                ),
              ),
            ],
          ),
          if (data.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...data.warnings.map((w) => _buildWarningTile(w, theme)),
          ],
        ],
      );
    }

    // State 2: Safe based on available data
    if (data.isSafe) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không phát hiện cảnh báo nào dựa trên dữ liệu hiện tại.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pin và toạ độ vị trí của trẻ đều đang trong giới hạn an toàn bình thường.',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // State 3: Warnings or NeedsAttention
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.warnings.isEmpty)
          Text(
            data.statusMessage,
            style: const TextStyle(fontSize: 13),
          )
        else
          ...data.warnings.map((w) => _buildWarningTile(w, theme)),
      ],
    );
  }

  Widget _buildWarningTile(SafetyWarningModel warning, ThemeData theme) {
    final color = warning.severityColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning header
          Row(
            children: [
              Icon(warning.icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  warning.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (warning.reading != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    warning.reading!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Message
          Text(
            warning.message,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),

          // Suggested Action & Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.arrow_right, size: 16, color: color),
              Expanded(
                child: Text(
                  warning.suggestedAction,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (warning.canRefreshLocation || warning.isStaleLocation || warning.isNoLocation)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _handleAction(warning),
                  child: const Text('Làm mới', style: TextStyle(fontSize: 11)),
                )
              else if (warning.canPairDevice || warning.isNoDevice)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _handleAction(warning),
                  child: const Text('Ghép nối', style: TextStyle(fontSize: 11)),
                )
              else if (warning.canContactChild || warning.canChargeDevice)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _handleAction(warning),
                  child: const Text('Chi tiết', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


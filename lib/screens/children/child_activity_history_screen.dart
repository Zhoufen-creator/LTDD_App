import 'package:flutter/material.dart';
import '../../models/child_activity_history_model.dart';
import '../../services/activity_service.dart';

class ChildActivityHistoryScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildActivityHistoryScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildActivityHistoryScreen> createState() => _ChildActivityHistoryScreenState();
}

class _ChildActivityHistoryScreenState extends State<ChildActivityHistoryScreen> {
  final ActivityService _activityService = ActivityService();

  bool _isLoading = true;
  String? _errorMessage;
  ChildActivityHistoryModel? _data;
  String _selectedFilter = 'All'; // All, AppSession, Screen, RuleViolation
  final int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchActivityHistory();
  }

  Future<void> _fetchActivityHistory({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      String? eventTypeParam;
      if (_selectedFilter == 'AppSession') {
        eventTypeParam = 'AppSession';
      } else if (_selectedFilter == 'RuleViolation') {
        eventTypeParam = 'RuleViolation';
      }

      final result = await _activityService.getChildActivityHistory(
        widget.childId,
        eventType: eventTypeParam,
        page: _currentPage,
        pageSize: 50,
      );

      setState(() {
        _data = result;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể tải lịch sử hoạt động: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$h:$m - $d/$mo';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = (seconds / 60).floor();
    if (m < 1) return '$seconds giây';
    if (m < 60) return '$m phút';
    final h = (m / 60).floor();
    final rem = m % 60;
    return '${h}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _data?.summary;
    final events = _data?.events ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Hoạt động của ${widget.childName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => _fetchActivityHistory(isRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _fetchActivityHistory(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchActivityHistory(isRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Today's Usage Summary Cards
                      if (summary != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Thời gian dùng máy',
                                value: summary.formattedScreenTime,
                                icon: Icons.timer_outlined,
                                color: Colors.blue,
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Vi phạm quy tắc',
                                value: '${summary.ruleViolationsToday} lần',
                                icon: Icons.block,
                                color: summary.ruleViolationsToday > 0 ? Colors.red : Colors.green,
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Mở khóa máy',
                                value: '${summary.screenUnlockCountToday} lần',
                                icon: Icons.lock_open,
                                color: Colors.purple,
                                theme: theme,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Top Apps Today
                        if (summary.topAppsToday.isNotEmpty) ...[
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.leaderboard_outlined, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ứng dụng dùng nhiều nhất hôm nay',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  for (final app in summary.topAppsToday)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: theme.colorScheme.primaryContainer,
                                            child: Icon(Icons.apps, size: 16, color: theme.colorScheme.primary),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  app.appName.isNotEmpty ? app.appName : app.packageName,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${app.sessionCount} phiên sử dụng',
                                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            app.formattedDuration,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'Tất cả'),
                            const SizedBox(width: 8),
                            _buildFilterChip('AppSession', 'Ứng dụng'),
                            const SizedBox(width: 8),
                            _buildFilterChip('RuleViolation', 'Vi phạm quy tắc'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Activity Timeline
                      if (events.isEmpty) ...[
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'Chưa ghi nhận hoạt động nào trong khoảng thời gian này.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Nhật ký hoạt động chi tiết (${events.length} sự kiện)',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        for (final ev in events) _buildActivityItem(ev, theme),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _fetchActivityHistory();
        }
      },
    );
  }

  Widget _buildActivityItem(ActivityLogModel ev, ThemeData theme) {
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;

    switch (ev.eventType) {
      case 'AppSession':
        icon = Icons.apps;
        iconColor = Colors.blue;
        title = ev.appName?.isNotEmpty == true ? ev.appName! : (ev.packageName ?? 'Ứng dụng');
        subtitle = ev.durationSeconds != null ? 'Thời lượng: ${_formatDuration(ev.durationSeconds)}' : 'Sử dụng ứng dụng';
        break;
      case 'RuleViolation':
        icon = Icons.warning_rounded;
        iconColor = Colors.red;
        title = 'Vi phạm: ${ev.violationAction ?? "Quy tắc bị chặn"}';
        subtitle = ev.violationDetails ?? 'Đã can thiệp ngăn chặn hoạt động';
        break;
      case 'ScreenOn':
        icon = Icons.brightness_medium;
        iconColor = Colors.amber.shade700;
        title = 'Màn hình bật';
        subtitle = 'Thiết bị kích hoạt sáng màn hình';
        break;
      case 'ScreenOff':
        icon = Icons.brightness_2;
        iconColor = Colors.blueGrey;
        title = 'Màn hình tắt';
        subtitle = 'Thiết bị tắt màn hình / nghỉ ngơi';
        break;
      case 'DeviceUnlocked':
        icon = Icons.lock_open;
        iconColor = Colors.green;
        title = 'Mở khóa thiết bị';
        subtitle = 'Trẻ mở khóa màn hình';
        break;
      case 'DeviceLocked':
        icon = Icons.lock_outline;
        iconColor = Colors.grey;
        title = 'Khóa màn hình';
        subtitle = 'Thiết bị đã khóa';
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.teal;
        title = ev.eventType;
        subtitle = ev.packageName ?? '';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: ev.eventType == 'RuleViolation'
              ? Colors.red.shade300
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            color: ev.eventType == 'RuleViolation' ? Colors.red.shade900 : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              'Thiết bị: ${ev.deviceName} • ${_formatDateTime(ev.recordedAt)}',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

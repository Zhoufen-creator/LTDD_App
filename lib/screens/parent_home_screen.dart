import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/child_model.dart';
import '../models/device_mode_request_model.dart';
import '../models/device_model.dart';
import '../models/monitoring_rule_model.dart';
import '../providers/auth_provider.dart';
import '../providers/children_provider.dart';
import '../providers/devices_provider.dart';
import '../providers/monitoring_rules_provider.dart';
import '../services/device_service.dart';
import 'children/child_form_dialog.dart';
import 'children/child_location_dialog.dart';
import 'children/child_activity_history_screen.dart';
import 'children/pairing_qr_dialog.dart';
import 'devices/device_form_dialog.dart';
import 'login_screen.dart';
import 'rules/rule_form_dialog.dart';
import '../widgets/biometric_enrollment_dialog.dart';
import '../widgets/safety_advisor_card.dart';

/// Central dashboard for Parents to manage Children, Devices, and Monitoring Rules.
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentTabIndex = 0;
  List<DeviceModeRequestModel> _pendingModeRequests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    context.read<ChildrenProvider>().fetchChildren();
    context.read<DevicesProvider>().fetchDevices();
    context.read<MonitoringRulesProvider>().fetchRules();
    _fetchPendingModeRequests();
  }

  Future<void> _fetchPendingModeRequests() async {
    try {
      final reqs = await context.read<DeviceService>().getPendingModeRequests();
      if (mounted) {
        setState(() {
          _pendingModeRequests = reqs;
        });
      }
    } catch (_) {}
  }

  Future<void> _approveModeRequest(DeviceModeRequestModel request) async {
    try {
      await context.read<DeviceService>().approveModeRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã phê duyệt yêu cầu từ thiết bị của ${request.childName}.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _fetchPendingModeRequests();
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phê duyệt thất bại: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _rejectModeRequest(DeviceModeRequestModel request) async {
    try {
      await context.read<DeviceService>().rejectModeRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã từ chối yêu cầu từ thiết bị của ${request.childName}.'),
          ),
        );
        _fetchPendingModeRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Từ chối thất bại: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showAddDialog() {
    if (_currentTabIndex == 0) {
      showDialog(
        context: context,
        builder: (_) => const ChildFormDialog(),
      );
    } else if (_currentTabIndex == 1) {
      final children = context.read<ChildrenProvider>().children;
      if (children.isEmpty) {
        _showNoChildrenAlert('thiết bị');
        return;
      }
      showDialog(
        context: context,
        builder: (_) => const DeviceFormDialog(),
      );
    } else {
      final children = context.read<ChildrenProvider>().children;
      if (children.isEmpty) {
        _showNoChildrenAlert('quy tắc giám sát');
        return;
      }
      showDialog(
        context: context,
        builder: (_) => const RuleFormDialog(),
      );
    }
  }

  void _showNoChildrenAlert(String moduleName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chưa có hồ sơ trẻ em'),
        content: Text(
          'Bạn cần tạo ít nhất một hồ sơ trẻ em trước khi thêm $moduleName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _currentTabIndex = 0;
              });
              showDialog(
                context: context,
                builder: (_) => const ChildFormDialog(),
              );
            },
            child: const Text('Thêm trẻ em ngay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;

    final titles = [
      'Quản lý Trẻ em',
      'Quản lý Thiết bị',
      'Quy tắc Giám sát',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              titles[_currentTabIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (user != null)
              Text(
                'Phụ huynh: ${user.fullName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cài đặt Sinh trắc học',
            icon: const Icon(Icons.fingerprint),
            onPressed: () => BiometricEnrollmentDialog.showSettingsDialog(context),
          ),
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildChildrenTab(),
          _buildDevicesTab(),
          _buildRulesTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.child_care_outlined),
            selectedIcon: Icon(Icons.child_care),
            label: 'Trẻ em',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Thiết bị',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: 'Quy tắc',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: Text(_currentTabIndex == 0
            ? 'Thêm trẻ'
            : _currentTabIndex == 1
                ? 'Thêm thiết bị'
                : 'Thêm quy tắc'),
      ),
    );
  }

  // =========================================================================
  // TAB 1: CHILDREN
  // =========================================================================
  Widget _buildChildrenTab() {
    final theme = Theme.of(context);
    final provider = context.watch<ChildrenProvider>();

    if (provider.isLoading && provider.children.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.children.isEmpty) {
      return _buildErrorState(
        message: provider.errorMessage!,
        onRetry: () => provider.fetchChildren(),
      );
    }

    if (provider.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPendingModeRequestsBanner(theme),
          _buildEmptyState(
            icon: Icons.child_care_outlined,
            title: 'Chưa có hồ sơ trẻ em nào',
            subtitle: 'Bắt đầu quản lý an toàn bằng cách tạo hồ sơ trẻ em đầu tiên.',
            buttonLabel: 'Thêm hồ sơ trẻ em',
            onAction: () => showDialog(
              context: context,
              builder: (_) => const ChildFormDialog(),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchChildren();
        await _fetchPendingModeRequests();
      },
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        children: [
          _buildPendingModeRequestsBanner(theme),
          ...provider.children.map((child) => _buildChildCard(child)),
        ],
      ),
    );
  }

  Widget _buildPendingModeRequestsBanner(ThemeData theme) {
    if (_pendingModeRequests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notification_important, color: Colors.amber.shade900, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Yêu cầu thay đổi chế độ từ thiết bị trẻ em (${_pendingModeRequests.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._pendingModeRequests.map((req) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bé: ${req.childName}  •  Thiết bị: ${req.deviceName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hành động xin phép: ${req.targetModeLabelVi}',
                    style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  if (req.reason != null && req.reason!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Lý do: "${req.reason}"',
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Từ chối'),
                        onPressed: () => _rejectModeRequest(req),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Phê duyệt'),
                        onPressed: () => _approveModeRequest(req),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChildCard(ChildModel child) {
    final theme = Theme.of(context);
    final devicesProvider = context.watch<DevicesProvider>();
    final childDevices = devicesProvider.devices.where((d) => d.childId == child.id).toList();
    final primaryDevice = childDevices.where((d) => d.batteryPercentage != null).firstOrNull ?? childDevices.firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    child.fullName.isNotEmpty ? child.fullName[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        child.dateOfBirth != null
                            ? '${child.age ?? 0} tuổi • Sinh: ${child.dateOfBirth!.day.toString().padLeft(2, '0')}/${child.dateOfBirth!.month.toString().padLeft(2, '0')}/${child.dateOfBirth!.year}'
                            : 'Chưa cập nhật ngày sinh',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'location') {
                      showDialog(
                        context: context,
                        builder: (_) => ChildLocationDialog(child: child),
                      );
                    } else if (action == 'activities') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChildActivityHistoryScreen(
                            childId: child.id,
                            childName: child.fullName,
                          ),
                        ),
                      );
                    } else if (action == 'qr') {
                      showDialog(
                        context: context,
                        builder: (_) => PairingQrDialog(child: child),
                      );
                    } else if (action == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => ChildFormDialog(child: child),
                      );
                    } else if (action == 'delete') {
                      _confirmDeleteChild(child);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'location',
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Vị trí GPS'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'activities',
                      child: Row(
                        children: [
                          Icon(Icons.history_toggle_off, size: 20),
                          SizedBox(width: 8),
                          Text('Lịch sử hoạt động'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'qr',
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_2, size: 20),
                          SizedBox(width: 8),
                          Text('Ghép nối QR'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Chỉnh sửa'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Xóa hồ sơ', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.location_on_outlined, size: 16),
                  label: const Text('Vị trí'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ChildLocationDialog(child: child),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.history_toggle_off, size: 16),
                  label: const Text('Hoạt động'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChildActivityHistoryScreen(
                          childId: child.id,
                          childName: child.fullName,
                        ),
                      ),
                    );
                  },
                ),
                if (primaryDevice != null && primaryDevice.batteryPercentage != null)
                  ActionChip(
                    avatar: Icon(
                      primaryDevice.isCharging == true
                          ? Icons.battery_charging_full
                          : (primaryDevice.isLowBattery ? Icons.battery_alert : Icons.battery_std),
                      size: 16,
                      color: primaryDevice.isLowBattery
                          ? Colors.red.shade700
                          : (primaryDevice.isCharging == true ? Colors.amber.shade900 : Colors.green.shade700),
                    ),
                    backgroundColor: primaryDevice.isLowBattery ? Colors.red.shade50 : null,
                    label: Text(
                      '${primaryDevice.batteryPercentage}%${primaryDevice.isCharging == true ? " ⚡" : ""}',
                      style: TextStyle(
                        color: primaryDevice.isLowBattery ? Colors.red.shade900 : null,
                        fontWeight: primaryDevice.isLowBattery ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    tooltip: 'Tình trạng pin thiết bị (${primaryDevice.deviceName})',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ChildLocationDialog(child: child),
                      );
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.qr_code_2, size: 16),
                  label: const Text('Ghép nối QR'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => PairingQrDialog(child: child),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.devices, size: 16),
                  label: Text('${child.deviceCount} thiết bị'),
                  onPressed: () {
                    context.read<DevicesProvider>().setFilterChildId(child.id);
                    setState(() {
                      _currentTabIndex = 1;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.rule, size: 16),
                  label: Text('${child.monitoringRuleCount} quy tắc'),
                  onPressed: () {
                    context.read<MonitoringRulesProvider>().setFilterChildId(child.id);
                    setState(() {
                      _currentTabIndex = 2;
                    });
                  },
                ),
              ],
            ),
            SafetyAdvisorCard(child: child),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChild(ChildModel child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa hồ sơ'),
        content: Text(
          'Bạn có chắc chắn muốn xóa hồ sơ của "${child.fullName}"?\n\n'
          'Cảnh báo: Hành động này sẽ tự động xóa tất cả thiết bị và quy tắc giám sát gắn liền với trẻ em này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa hồ sơ'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<ChildrenProvider>().deleteChild(child.id);
      if (mounted) {
        if (success) {
          // Also refresh devices and rules as backend cascades deletion
          context.read<DevicesProvider>().fetchDevices();
          context.read<MonitoringRulesProvider>().fetchRules();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa hồ sơ của ${child.fullName}.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final error = context.read<ChildrenProvider>().errorMessage ?? 'Xóa thất bại.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // =========================================================================
  // TAB 2: DEVICES
  // =========================================================================
  Widget _buildDevicesTab() {
    final devicesProvider = context.watch<DevicesProvider>();
    final children = context.watch<ChildrenProvider>().children;

    return Column(
      children: [
        // Filter dropdown
        if (children.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 8),
                const Text('Lọc theo trẻ: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: devicesProvider.filterChildId,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả thiết bị'),
                      ),
                      ...children.map((c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.fullName),
                          )),
                    ],
                    onChanged: (val) {
                      devicesProvider.setFilterChildId(val);
                    },
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: Builder(builder: (context) {
            if (devicesProvider.isLoading && devicesProvider.devices.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (devicesProvider.errorMessage != null && devicesProvider.devices.isEmpty) {
              return _buildErrorState(
                message: devicesProvider.errorMessage!,
                onRetry: () => devicesProvider.fetchDevices(),
              );
            }

            if (devicesProvider.isEmpty) {
              return _buildEmptyState(
                icon: Icons.devices_other_outlined,
                title: 'Chưa có thiết bị nào',
                subtitle: 'Đăng ký điện thoại hoặc máy tính bảng của con để bắt đầu giám sát.',
                buttonLabel: 'Đăng ký thiết bị',
                onAction: () => _showAddDialog(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => devicesProvider.fetchDevices(),
              child: ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 88),
                itemCount: devicesProvider.devices.length,
                itemBuilder: (context, index) {
                  final device = devicesProvider.devices[index];
                  final childName = children
                      .where((c) => c.id == device.childId)
                      .map((c) => c.fullName)
                      .firstOrNull ?? 'ID #${device.childId}';
                  return _buildDeviceCard(device, childName);
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(DeviceModel device, String childName) {
    final theme = Theme.of(context);
    final provider = context.read<DevicesProvider>();

    IconData platformIcon = Icons.phone_android;
    final plat = (device.platform ?? '').toLowerCase();
    if (plat.contains('ios') || plat.contains('apple') || plat.contains('iphone')) {
      platformIcon = Icons.phone_iphone;
    } else if (plat.contains('ipad') || plat.contains('tab')) {
      platformIcon = Icons.tablet_mac;
    } else if (plat.contains('win') || plat.contains('mac') || plat.contains('pc')) {
      platformIcon = Icons.laptop;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: device.isActive
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            platformIcon,
            color: device.isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          device.deviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Gán cho: $childName • ${device.platform ?? "Chưa rõ HĐH"}'),
            if (device.deviceIdentifier != null && device.deviceIdentifier!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Mã máy: ${device.deviceIdentifier}',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: device.isActive
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    device.isActive ? 'Đang kích hoạt' : 'Tạm dừng',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: device.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (device.batteryPercentage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: device.isLowBattery
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          device.isCharging == true
                              ? Icons.bolt
                              : (device.isLowBattery ? Icons.battery_alert : Icons.battery_std),
                          size: 13,
                          color: device.isLowBattery ? Colors.red.shade800 : Colors.blue.shade800,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${device.batteryPercentage}%${device.isCharging == true ? " (Sạc)" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: device.isLowBattery ? Colors.red.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: device.isActive,
              onChanged: (val) {
                provider.toggleDeviceStatus(device);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  showDialog(
                    context: context,
                    builder: (_) => DeviceFormDialog(device: device),
                  );
                } else if (action == 'delete') {
                  _confirmDeleteDevice(device);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Chỉnh sửa'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xóa thiết bị', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa thiết bị'),
        content: Text('Bạn có chắc muốn xóa thiết bị "${device.deviceName}" khỏi hệ thống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<DevicesProvider>().deleteDevice(device.id);
      if (mounted) {
        if (success) {
          context.read<ChildrenProvider>().fetchChildren();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa thiết bị ${device.deviceName}.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final error = context.read<DevicesProvider>().errorMessage ?? 'Xóa thất bại.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // =========================================================================
  // TAB 3: MONITORING RULES
  // =========================================================================
  Widget _buildRulesTab() {
    final rulesProvider = context.watch<MonitoringRulesProvider>();
    final children = context.watch<ChildrenProvider>().children;

    return Column(
      children: [
        // Filter dropdown
        if (children.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 8),
                const Text('Lọc theo trẻ: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: rulesProvider.filterChildId,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả quy tắc'),
                      ),
                      ...children.map((c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.fullName),
                          )),
                    ],
                    onChanged: (val) {
                      rulesProvider.setFilterChildId(val);
                    },
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: Builder(builder: (context) {
            if (rulesProvider.isLoading && rulesProvider.rules.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (rulesProvider.errorMessage != null && rulesProvider.rules.isEmpty) {
              return _buildErrorState(
                message: rulesProvider.errorMessage!,
                onRetry: () => rulesProvider.fetchRules(),
              );
            }

            if (rulesProvider.isEmpty) {
              return _buildEmptyState(
                icon: Icons.security_outlined,
                title: 'Chưa có quy tắc giám sát nào',
                subtitle: 'Thiết lập giới hạn thời gian hoặc bảo vệ nội dung cho các con.',
                buttonLabel: 'Tạo quy tắc mới',
                onAction: () => _showAddDialog(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => rulesProvider.fetchRules(),
              child: ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 88),
                itemCount: rulesProvider.rules.length,
                itemBuilder: (context, index) {
                  final rule = rulesProvider.rules[index];
                  final childName = children
                      .where((c) => c.id == rule.childId)
                      .map((c) => c.fullName)
                      .firstOrNull ?? 'ID #${rule.childId}';
                  return _buildRuleCard(rule, childName);
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRuleCard(MonitoringRuleModel rule, String childName) {
    final theme = Theme.of(context);
    final provider = context.read<MonitoringRulesProvider>();

    IconData ruleIcon = Icons.rule;
    final rType = rule.ruleType.toLowerCase();
    if (rType.contains('time')) {
      ruleIcon = Icons.hourglass_top_outlined;
    } else if (rType.contains('app') || rType.contains('block')) {
      ruleIcon = Icons.block_outlined;
    } else if (rType.contains('web')) {
      ruleIcon = Icons.public_off_outlined;
    } else if (rType.contains('bed')) {
      ruleIcon = Icons.bedtime_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: rule.isEnabled
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            ruleIcon,
            color: rule.isEnabled
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          rule.ruleName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Áp dụng: $childName • Loại: ${rule.ruleType}'),
            if (rule.description != null && rule.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                rule.description!,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rule.isEnabled
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rule.isEnabled ? 'Đang áp dụng' : 'Đang tạm dừng',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: rule.isEnabled ? Colors.blue.shade800 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.isEnabled,
              onChanged: (val) {
                provider.toggleRuleStatus(rule);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  showDialog(
                    context: context,
                    builder: (_) => RuleFormDialog(rule: rule),
                  );
                } else if (action == 'delete') {
                  _confirmDeleteRule(rule);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Chỉnh sửa'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xóa quy tắc', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRule(MonitoringRuleModel rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa quy tắc'),
        content: Text('Bạn có chắc muốn xóa quy tắc "${rule.ruleName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<MonitoringRulesProvider>().deleteRule(rule.id);
      if (mounted) {
        if (success) {
          context.read<ChildrenProvider>().fetchChildren();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa quy tắc ${rule.ruleName}.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final error = context.read<MonitoringRulesProvider>().errorMessage ?? 'Xóa thất bại.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // =========================================================================
  // HELPER STATES: EMPTY & ERROR
  // =========================================================================
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

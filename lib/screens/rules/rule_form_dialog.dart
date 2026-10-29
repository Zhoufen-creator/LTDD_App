import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/monitoring_rule_model.dart';
import '../../providers/children_provider.dart';
import '../../providers/monitoring_rules_provider.dart';

/// Modal dialog for adding or editing a Monitoring Rule with specific execution parameters.
class RuleFormDialog extends StatefulWidget {
  final MonitoringRuleModel? rule;
  final int? preselectedChildId;

  const RuleFormDialog({
    super.key,
    this.rule,
    this.preselectedChildId,
  });

  @override
  State<RuleFormDialog> createState() => _RuleFormDialogState();
}

class _RuleFormDialogState extends State<RuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  // Rule specific configuration controllers
  late final TextEditingController _packageController;
  late final TextEditingController _appNameController;
  int _dailyLimitMinutes = 60;
  TimeOfDay _bedtimeStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _bedtimeEnd = const TimeOfDay(hour: 6, minute: 0);
  List<int> _bedtimeDays = [1, 2, 3, 4, 5, 6, 7];

  int? _selectedChildId;
  String _selectedRuleType = 'TimeLimit';
  bool _isEnabled = true;
  bool _isSubmitting = false;

  bool get isEditing => widget.rule != null;

  static const Map<String, String> _ruleTypeLabels = {
    'TimeLimit': 'Giới hạn thời gian sử dụng ứng dụng',
    'AppBlock': 'Chặn ứng dụng hoàn toàn',
    'BedTime': 'Quy tắc giờ đi ngủ (Khóa máy theo giờ)',
    'WebFilter': 'Lọc nội dung Web (Mạng/DNS)',
    'ContentFilter': 'Kiểm duyệt nội dung',
    'Custom': 'Tùy chỉnh khác',
  };

  static const List<Map<String, String>> _popularApps = [
    {'name': 'TikTok', 'package': 'com.zhiliaoapp.musically'},
    {'name': 'YouTube', 'package': 'com.google.android.youtube'},
    {'name': 'Facebook', 'package': 'com.facebook.katana'},
    {'name': 'Roblox', 'package': 'com.roblox.client'},
    {'name': 'Free Fire', 'package': 'com.dts.freefireth'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?.ruleName ?? '');
    _descriptionController = TextEditingController(text: widget.rule?.description ?? '');
    _packageController = TextEditingController();
    _appNameController = TextEditingController();

    _selectedChildId = widget.rule?.childId ?? widget.preselectedChildId;
    if (widget.rule != null) {
      _selectedRuleType = _ruleTypeLabels.containsKey(widget.rule!.ruleType)
          ? widget.rule!.ruleType
          : 'Custom';

      // Parse existing config if available
      if (widget.rule!.appBlockConfig != null) {
        final cfg = widget.rule!.appBlockConfig!;
        _packageController.text = cfg.targetPackage;
        _appNameController.text = cfg.appName;
      } else if (widget.rule!.timeLimitConfig != null) {
        final cfg = widget.rule!.timeLimitConfig!;
        _packageController.text = cfg.targetPackage;
        _appNameController.text = cfg.appName;
        _dailyLimitMinutes = cfg.dailyLimitMinutes;
      } else if (widget.rule!.bedTimeConfig != null) {
        final cfg = widget.rule!.bedTimeConfig!;
        _bedtimeDays = List<int>.from(cfg.daysOfWeek);
        final startParts = cfg.bedtimeStart.split(':');
        if (startParts.length >= 2) {
          _bedtimeStart = TimeOfDay(
            hour: int.tryParse(startParts[0]) ?? 22,
            minute: int.tryParse(startParts[1]) ?? 0,
          );
        }
        final endParts = cfg.bedtimeEnd.split(':');
        if (endParts.length >= 2) {
          _bedtimeEnd = TimeOfDay(
            hour: int.tryParse(endParts[0]) ?? 6,
            minute: int.tryParse(endParts[1]) ?? 0,
          );
        }
      }
    } else {
      _packageController.text = 'com.zhiliaoapp.musically';
      _appNameController.text = 'TikTok';
    }

    _isEnabled = widget.rule?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _packageController.dispose();
    _appNameController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String? _buildRuleConfigJson() {
    if (_selectedRuleType == 'AppBlock') {
      return jsonEncode({
        'targetPackage': _packageController.text.trim(),
        'appName': _appNameController.text.trim().isNotEmpty
            ? _appNameController.text.trim()
            : _packageController.text.trim(),
      });
    } else if (_selectedRuleType == 'TimeLimit') {
      return jsonEncode({
        'targetPackage': _packageController.text.trim(),
        'appName': _appNameController.text.trim().isNotEmpty
            ? _appNameController.text.trim()
            : _packageController.text.trim(),
        'dailyLimitMinutes': _dailyLimitMinutes,
      });
    } else if (_selectedRuleType == 'BedTime') {
      return jsonEncode({
        'bedtimeStart': _formatTimeOfDay(_bedtimeStart),
        'bedtimeEnd': _formatTimeOfDay(_bedtimeEnd),
        'daysOfWeek': _bedtimeDays,
        'timezone': 'Asia/Ho_Chi_Minh',
      });
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hồ sơ trẻ em áp dụng quy tắc này.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final rulesProvider = context.read<MonitoringRulesProvider>();

    setState(() {
      _isSubmitting = true;
    });

    final ruleConfig = _buildRuleConfigJson();

    bool success;
    if (isEditing) {
      success = await rulesProvider.updateRule(
        id: widget.rule!.id,
        ruleName: _nameController.text.trim(),
        ruleType: _selectedRuleType,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        ruleConfig: ruleConfig,
        isEnabled: _isEnabled,
        childId: _selectedChildId,
      );
    } else {
      success = await rulesProvider.addRule(
        ruleName: _nameController.text.trim(),
        ruleType: _selectedRuleType,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        ruleConfig: ruleConfig,
        childId: _selectedChildId!,
        isEnabled: _isEnabled,
      );
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing
              ? 'Đã cập nhật quy tắc giám sát.'
              : 'Đã tạo quy tắc giám sát mới thành công.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rulesProvider.errorMessage ?? 'Thao tác thất bại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<ChildrenProvider>().children;
    final theme = Theme.of(context);

    if (_selectedChildId == null && children.isNotEmpty) {
      _selectedChildId = children.first.id;
    }

    return AlertDialog(
      title: Text(isEditing ? 'Chỉnh sửa quy tắc' : 'Tạo quy tắc giám sát mới'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Target Child Dropdown
                DropdownButtonFormField<int>(
                  initialValue: _selectedChildId,
                  decoration: const InputDecoration(
                    labelText: 'Áp dụng cho trẻ *',
                    prefixIcon: Icon(Icons.child_care),
                  ),
                  items: children.map((c) {
                    return DropdownMenuItem<int>(
                      value: c.id,
                      child: Text(c.fullName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedChildId = val;
                    });
                  },
                  validator: (val) => val == null ? 'Vui lòng chọn trẻ em' : null,
                ),
                const SizedBox(height: 16),

                // Rule Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên quy tắc *',
                    hintText: 'Ví dụ: Giới hạn dùng máy tối đa 2 giờ',
                    prefixIcon: Icon(Icons.rule),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên quy tắc';
                    }
                    if (value.trim().length > 100) {
                      return 'Tên quy tắc tối đa 100 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Rule Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedRuleType,
                  decoration: const InputDecoration(
                    labelText: 'Phân loại quy tắc',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _ruleTypeLabels.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRuleType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Specific rule type configuration parameters
                if (_selectedRuleType == 'AppBlock' || _selectedRuleType == 'TimeLimit') ...[
                  Text(
                    'Chọn ứng dụng mục tiêu:',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _popularApps.map((app) {
                      final isSelected = _packageController.text == app['package'];
                      return ChoiceChip(
                        label: Text(app['name']!),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _packageController.text = app['package']!;
                              _appNameController.text = app['name']!;
                              if (_nameController.text.isEmpty) {
                                _nameController.text = _selectedRuleType == 'AppBlock'
                                    ? 'Khóa ${app['name']}'
                                    : 'Giới hạn ${app['name']}';
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _appNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên ứng dụng *',
                      prefixIcon: Icon(Icons.apps),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên ứng dụng' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _packageController,
                    decoration: const InputDecoration(
                      labelText: 'Tên gói Android (Package Name) *',
                      hintText: 'com.example.app',
                      prefixIcon: Icon(Icons.android),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mã gói ứng dụng' : null,
                  ),
                  if (_selectedRuleType == 'TimeLimit') ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Giới hạn thời gian mỗi ngày:'),
                        Text(
                          '$_dailyLimitMinutes phút',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _dailyLimitMinutes.toDouble(),
                      min: 15,
                      max: 240,
                      divisions: 15,
                      label: '$_dailyLimitMinutes phút',
                      onChanged: (val) {
                        setState(() {
                          _dailyLimitMinutes = val.round();
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                ] else if (_selectedRuleType == 'BedTime') ...[
                  Text(
                    'Cấu hình giờ đi ngủ (Hỗ trợ qua đêm):',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.bedtime, size: 16),
                          label: Text('Bắt đầu: ${_formatTimeOfDay(_bedtimeStart)}'),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _bedtimeStart,
                            );
                            if (picked != null) {
                              setState(() => _bedtimeStart = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                          label: Text('Kết thúc: ${_formatTimeOfDay(_bedtimeEnd)}'),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _bedtimeEnd,
                            );
                            if (picked != null) {
                              setState(() => _bedtimeEnd = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else if (_selectedRuleType == 'WebFilter' || _selectedRuleType == 'ContentFilter') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Phạm vi hỗ trợ kỹ thuật: Trên Android tiêu chuẩn, việc lọc URL hoặc nội dung trong các trình duyệt ngoài (Chrome, Edge) yêu cầu cấu hình VPN hệ thống hoặc DNS bảo mật. Quy tắc này được lưu để chuẩn bị chính sách giám sát.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết (Tùy chọn)',
                    hintText: 'Nhập ghi chú hoặc yêu cầu cụ thể cho quy tắc...',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().length > 500) {
                      return 'Mô tả không được vượt quá 500 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // IsEnabled Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật kích hoạt quy tắc'),
                  subtitle: Text(
                    _isEnabled ? 'Quy tắc đang có hiệu lực' : 'Đang tạm dừng quy tắc',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isEnabled,
                  onChanged: (val) {
                    setState(() {
                      _isEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Lưu thay đổi' : 'Tạo quy tắc'),
        ),
      ],
    );
  }
}

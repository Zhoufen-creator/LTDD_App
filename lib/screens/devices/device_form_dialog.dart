import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device_model.dart';
import '../../providers/children_provider.dart';
import '../../providers/devices_provider.dart';

/// Modal dialog for adding or editing a Device.
class DeviceFormDialog extends StatefulWidget {
  final DeviceModel? device;
  final int? preselectedChildId;

  const DeviceFormDialog({
    super.key,
    this.device,
    this.preselectedChildId,
  });

  @override
  State<DeviceFormDialog> createState() => _DeviceFormDialogState();
}

class _DeviceFormDialogState extends State<DeviceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _identifierController;

  int? _selectedChildId;
  String _selectedPlatform = 'Android';
  bool _isActive = true;
  bool _isSubmitting = false;

  bool get isEditing => widget.device != null;

  static const List<String> _platforms = [
    'Android',
    'iOS',
    'iPadOS',
    'Windows',
    'macOS',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device?.deviceName ?? '');
    _identifierController = TextEditingController(text: widget.device?.deviceIdentifier ?? '');

    _selectedChildId = widget.device?.childId ?? widget.preselectedChildId;
    if (widget.device != null && widget.device!.platform != null) {
      _selectedPlatform = _platforms.contains(widget.device!.platform)
          ? widget.device!.platform!
          : 'Khác';
    }
    _isActive = widget.device?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hồ sơ trẻ em sở hữu thiết bị này.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final devicesProvider = context.read<DevicesProvider>();

    setState(() {
      _isSubmitting = true;
    });

    bool success;
    if (isEditing) {
      success = await devicesProvider.updateDevice(
        id: widget.device!.id,
        deviceName: _nameController.text.trim(),
        deviceIdentifier: _identifierController.text.trim().isNotEmpty
            ? _identifierController.text.trim()
            : null,
        platform: _selectedPlatform,
        isActive: _isActive,
        childId: _selectedChildId,
      );
    } else {
      success = await devicesProvider.addDevice(
        deviceName: _nameController.text.trim(),
        deviceIdentifier: _identifierController.text.trim().isNotEmpty
            ? _identifierController.text.trim()
            : null,
        platform: _selectedPlatform,
        childId: _selectedChildId!,
        isActive: _isActive,
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
              ? 'Đã cập nhật thông tin thiết bị.'
              : 'Đã thêm thiết bị mới thành công.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(devicesProvider.errorMessage ?? 'Thao tác thất bại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<ChildrenProvider>().children;

    // Ensure selected child still exists in children list
    if (_selectedChildId == null && children.isNotEmpty) {
      _selectedChildId = children.first.id;
    }

    return AlertDialog(
      title: Text(isEditing ? 'Chỉnh sửa thiết bị' : 'Đăng ký thiết bị mới'),
      content: SingleChildScrollView(
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
                  labelText: 'Gán cho trẻ *',
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

              // Device Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên thiết bị *',
                  hintText: 'Ví dụ: Galaxy Tab của An',
                  prefixIcon: Icon(Icons.devices),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên thiết bị';
                  }
                  if (value.trim().length > 100) {
                    return 'Tên thiết bị tối đa 100 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Platform Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedPlatform,
                decoration: const InputDecoration(
                  labelText: 'Hệ điều hành / Nền tảng',
                  prefixIcon: Icon(Icons.phone_android),
                ),
                items: _platforms.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(p),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPlatform = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Device Identifier (Optional IMEI/Serial)
              TextFormField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Mã định danh (Tùy chọn)',
                  hintText: 'Số Serial / IMEI / UUID',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
              ),
              const SizedBox(height: 12),

              // IsActive Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kích hoạt quản lý'),
                subtitle: Text(
                  _isActive ? 'Thiết bị đang được áp dụng giám sát' : 'Tạm dừng giám sát thiết bị này',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _isActive,
                onChanged: (val) {
                  setState(() {
                    _isActive = val;
                  });
                },
              ),
            ],
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
              : Text(isEditing ? 'Lưu thay đổi' : 'Đăng ký'),
        ),
      ],
    );
  }
}

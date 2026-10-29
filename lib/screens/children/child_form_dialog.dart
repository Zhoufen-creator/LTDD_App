import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/children_provider.dart';

/// Modal dialog for adding or editing a Child profile.
class ChildFormDialog extends StatefulWidget {
  final ChildModel? child;

  const ChildFormDialog({super.key, this.child});

  @override
  State<ChildFormDialog> createState() => _ChildFormDialogState();
}

class _ChildFormDialogState extends State<ChildFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  DateTime? _selectedDob;
  bool _isSubmitting = false;

  bool get isEditing => widget.child != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.fullName ?? '');
    _selectedDob = widget.child?.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 8, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? initial : now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      helpText: 'Chọn ngày sinh của trẻ',
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final childrenProvider = context.read<ChildrenProvider>();
    final authProvider = context.read<AuthProvider>();
    final parentId = authProvider.user?.id ?? 0;

    setState(() {
      _isSubmitting = true;
    });

    bool success;
    if (isEditing) {
      success = await childrenProvider.updateChild(
        id: widget.child!.id,
        fullName: _nameController.text.trim(),
        dateOfBirth: _selectedDob,
      );
    } else {
      success = await childrenProvider.addChild(
        fullName: _nameController.text.trim(),
        dateOfBirth: _selectedDob,
        parentId: parentId,
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
              ? 'Đã cập nhật thông tin trẻ thành công.'
              : 'Đã thêm hồ sơ trẻ em thành công.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(childrenProvider.errorMessage ?? 'Thao tác thất bại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEditing ? 'Chỉnh sửa hồ sơ trẻ' : 'Thêm hồ sơ trẻ em mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên của trẻ *',
                  hintText: 'Ví dụ: Nguyễn Văn An',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ và tên của trẻ';
                  }
                  if (value.trim().length > 100) {
                    return 'Họ tên không được vượt quá 100 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined),
                title: Text(
                  _selectedDob == null
                      ? 'Ngày sinh: Chưa chọn'
                      : 'Ngày sinh: ${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}',
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: TextButton(
                  onPressed: _isSubmitting ? null : _pickDate,
                  child: Text(_selectedDob == null ? 'Chọn ngày' : 'Thay đổi'),
                ),
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
              : Text(isEditing ? 'Lưu thay đổi' : 'Thêm trẻ'),
        ),
      ],
    );
  }
}


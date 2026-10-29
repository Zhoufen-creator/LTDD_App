import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/pairing_ticket_model.dart';
import '../../providers/child_mode_provider.dart';
import '../mode_selection_screen.dart';
import 'child_home_screen.dart';

/// Screen allowing the child device to be enrolled using QR scan or manual pairing code.
class ChildEnrollmentScreen extends StatefulWidget {
  const ChildEnrollmentScreen({super.key});

  @override
  State<ChildEnrollmentScreen> createState() => _ChildEnrollmentScreenState();
}

class _ChildEnrollmentScreenState extends State<ChildEnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _deviceNameController = TextEditingController(text: 'Điện thoại của bé');

  @override
  void dispose() {
    _codeController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _submitEnrollment([String? explicitCode]) async {
    final codeToSubmit = explicitCode ?? _codeController.text;
    if (codeToSubmit.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập hoặc quét mã ghép nối.')),
      );
      return;
    }

    final provider = context.read<ChildModeProvider>();
    if (provider.isEnrolling) return;

    final success = await provider.enrollDevice(
      rawPairingCode: codeToSubmit,
      deviceName: _deviceNameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChildHomeScreen()),
      );
    }
  }

  void _openCameraScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) {
        bool hasDetected = false;
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                title: const Text('Quét mã QR từ Phụ huynh'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              Expanded(
                child: MobileScanner(
                  controller: MobileScannerController(
                    detectionSpeed: DetectionSpeed.noDuplicates,
                  ),
                  onDetect: (capture) {
                    if (hasDetected) return;
                    for (final barcode in capture.barcodes) {
                      final raw = barcode.rawValue;
                      if (raw != null && raw.isNotEmpty) {
                        hasDetected = true;
                        final extracted = PairingTicketModel.extractPairingCode(raw);
                        Navigator.of(ctx).pop();
                        _codeController.text = extracted;
                        _submitEnrollment(extracted);
                        break;
                      }
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Hướng camera về phía mã QR trên màn hình phụ huynh',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final childProvider = context.watch<ChildModeProvider>();
    final isEnrolling = childProvider.isEnrolling;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghép nối Thiết bị của Trẻ'),
        actions: [
          IconButton(
            tooltip: 'Đổi chế độ',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kích hoạt Chế độ Trẻ Em',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ghép nối thiết bị này với hồ sơ trẻ em do phụ huynh tạo để nhận quy tắc an toàn.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Camera Scan QR Button
                  FilledButton.icon(
                    onPressed: isEnrolling ? null : _openCameraScanner,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Mở camera quét mã QR'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'HOẶC NHẬP MÃ THỦ CÔNG',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Manual Pairing Code Input
                  TextFormField(
                    controller: _codeController,
                    enabled: !isEnrolling,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Mã ghép nối (ví dụ: PAIR-XXXX)',
                      hintText: 'Nhập mã ghép nối 8 ký tự',
                      prefixIcon: const Icon(Icons.vpn_key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập mã ghép nối.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Device Name Input
                  TextFormField(
                    controller: _deviceNameController,
                    enabled: !isEnrolling,
                    decoration: InputDecoration(
                      labelText: 'Tên thiết bị',
                      hintText: 'ví dụ: Galaxy Tab, iPhone Bé',
                      prefixIcon: const Icon(Icons.smartphone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Error Message Banner
                  if (childProvider.enrollmentError != null) ...[
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
                              childProvider.enrollmentError!,
                              style: TextStyle(color: theme.colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Submit Enrollment Button
                  FilledButton.tonal(
                    onPressed: isEnrolling
                        ? null
                        : () {
                            if (_formKey.currentState?.validate() ?? false) {
                              _submitEnrollment();
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isEnrolling
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Kích hoạt thiết bị',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Switch Mode Button
                  TextButton.icon(
                    onPressed: isEnrolling
                        ? null
                        : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                            );
                          },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Quay lại chọn chế độ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

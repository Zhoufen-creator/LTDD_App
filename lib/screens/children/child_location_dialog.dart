import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/child_model.dart';
import '../../models/device_location_model.dart';
import '../../models/device_model.dart';
import '../../models/location_refresh_request_model.dart';
import '../../services/api_service.dart';
import '../../services/device_service.dart';
import '../../services/location_service.dart';

/// Modal dialog for parents to inspect the latest GPS location, battery health,
/// and trigger on-demand location refreshes for a child's device.
class ChildLocationDialog extends StatefulWidget {
  final ChildModel child;
  final LocationService? locationServiceOverride;
  final DeviceService? deviceServiceOverride;

  const ChildLocationDialog({
    super.key,
    required this.child,
    this.locationServiceOverride,
    this.deviceServiceOverride,
  });

  @override
  State<ChildLocationDialog> createState() => _ChildLocationDialogState();
}

class _ChildLocationDialogState extends State<ChildLocationDialog> {
  DeviceLocationModel? _location;
  DeviceModel? _device;
  List<DeviceLocationModel> _history = [];
  bool _isLoading = true;
  bool _hasFetchedOnce = false;
  String? _errorMessage;

  // Location Refresh Request State
  bool _isRequestingRefresh = false;
  LocationRefreshRequestModel? _refreshRequestModel;
  String? _refreshStatusMessage;
  Timer? _refreshPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _refreshPollTimer?.cancel();
    super.dispose();
  }

  /// Fetches latest location and child devices concurrently.
  Future<void> _fetchData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final locationService = widget.locationServiceOverride ??
        context.read<LocationService>();
    DeviceService? deviceService = widget.deviceServiceOverride;
    if (deviceService == null) {
      try {
        deviceService = context.read<DeviceService>();
      } catch (_) {
        deviceService = null;
      }
    }

    try {
      final locFuture = locationService.getLatestChildLocation(
        childId: widget.child.id,
      );
      final devFuture = deviceService != null
          ? deviceService.getDevices(childId: widget.child.id)
          : Future.value(<DeviceModel>[]);
      final histFuture = locationService.getChildLocationHistory(
        childId: widget.child.id,
        limit: 20,
      );

      final results = await Future.wait([locFuture, devFuture, histFuture]);
      final loc = results[0] as DeviceLocationModel?;
      final devices = results[1] as List<DeviceModel>;
      final history = results[2] as List<DeviceLocationModel>;

      DeviceModel? matchedDevice;
      if (loc != null && loc.deviceId != 0) {
        matchedDevice = devices.where((d) => d.id == loc.deviceId).firstOrNull;
      }
      matchedDevice ??= devices.firstOrNull;

      if (!mounted) return;
      setState(() {
        _location = loc;
        _device = matchedDevice;
        _history = history;
        _isLoading = false;
        _hasFetchedOnce = true;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasFetchedOnce = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasFetchedOnce = true;
        _errorMessage = 'Không thể tải thông tin giám sát: $e';
      });
    }
  }

  /// Initiates a Parent-Requested Location Refresh command.
  Future<void> _requestLocationRefresh() async {
    if (_isRequestingRefresh) return;
    _refreshPollTimer?.cancel();

    setState(() {
      _isRequestingRefresh = true;
      _refreshStatusMessage = 'Đang gửi yêu cầu vị trí mới tới thiết bị...';
      _refreshRequestModel = null;
    });

    final locationService = widget.locationServiceOverride ??
        context.read<LocationService>();

    try {
      final request = await locationService.createRefreshRequest(
        childId: widget.child.id,
      );

      if (!mounted) return;
      setState(() {
        _refreshRequestModel = request;
        _refreshStatusMessage = request.statusLabelVi;
      });

      if (request.isCompleted) {
        await _fetchData(isSilent: true);
        if (mounted) {
          setState(() {
            _isRequestingRefresh = false;
          });
        }
        return;
      }

      // Start polling request status every 2 seconds (up to 15 cycles = 30 seconds)
      int pollCount = 0;
      const maxPolls = 15;

      _refreshPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        pollCount++;
        try {
          final updatedStatus = await locationService.getRefreshRequestStatus(
            requestId: request.id,
          );

          if (!mounted) {
            timer.cancel();
            return;
          }

          setState(() {
            _refreshRequestModel = updatedStatus;
            _refreshStatusMessage = updatedStatus.statusLabelVi;
          });

          if (updatedStatus.isCompleted) {
            timer.cancel();
            await _fetchData(isSilent: true);
            if (mounted) {
              setState(() {
                _isRequestingRefresh = false;
              });
            }
          } else if (updatedStatus.isFailed || updatedStatus.isExpired) {
            timer.cancel();
            if (mounted) {
              setState(() {
                _isRequestingRefresh = false;
              });
            }
          } else if (pollCount >= maxPolls) {
            timer.cancel();
            if (mounted) {
              setState(() {
                _isRequestingRefresh = false;
                _refreshStatusMessage =
                    'Thiết bị chưa phản hồi (hết thời gian chờ). Thiết bị có thể đang tắt hoặc không có mạng.';
              });
            }
          }
        } catch (e) {
          if (pollCount >= maxPolls) {
            timer.cancel();
            if (mounted) {
              setState(() {
                _isRequestingRefresh = false;
                _refreshStatusMessage = 'Lỗi khi kiểm tra phản hồi thiết bị: $e';
              });
            }
          }
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isRequestingRefresh = false;
        _refreshStatusMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRequestingRefresh = false;
        _refreshStatusMessage = 'Lỗi yêu cầu vị trí: $e';
      });
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở ứng dụng bản đồ.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi mở bản đồ: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.location_on,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vị trí của ${widget.child.fullName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Cập nhật từ thiết bị của trẻ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tải lại dữ liệu',
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _fetchData(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: _buildBody(theme),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        if (_location != null)
          FilledButton.icon(
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Mở bản đồ ngoài'),
            onPressed: () => _openInMaps(_location!.latitude, _location!.longitude),
          ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && !_hasFetchedOnce) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang truy vấn thông tin giám sát...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
              onPressed: () => _fetchData(),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Battery Health Section
        _buildBatteryCard(theme),

        const SizedBox(height: 14),

        // 2. Parent-Requested Location Refresh Section
        _buildRefreshRequestSection(theme),

        const SizedBox(height: 14),

        // 3. Location Details Section
        _buildLocationSection(theme),

        const SizedBox(height: 14),

        // 4. Location History & Movement Events Section
        _buildLocationHistorySection(theme),
      ],
    );
  }

  Widget _buildLocationHistorySection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Lịch sử vị trí & di chuyển',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_history.length} bản ghi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Chưa có lịch sử di chuyển nào được ghi nhận.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...List.generate(_history.length, (index) {
              final item = _history[index];
              Color badgeColor;
              IconData badgeIcon;

              if (item.isSignificantMovement) {
                badgeColor = Colors.blue.shade700;
                badgeIcon = Icons.directions_walk;
              } else if (item.isManualRefresh) {
                badgeColor = Colors.purple.shade700;
                badgeIcon = Icons.refresh;
              } else {
                badgeColor = Colors.teal.shade700;
                badgeIcon = Icons.schedule;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isSignificantMovement
                        ? Colors.blue.shade300
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 12, color: badgeColor),
                              const SizedBox(width: 4),
                              Text(
                                item.eventTypeFormatted,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.displacementMeters != null && item.displacementMeters! > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              '+${item.displacementFormatted}',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          item.relativeTimeFormatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          tooltip: 'Xem trên bản đồ',
                          onPressed: () => _openInMaps(item.latitude, item.longitude),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tọa độ: ${item.coordinatesFormatted}  |  Sai số: ${item.accuracyFormatted}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Thời gian: ${item.localTimestampFormatted}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(ThemeData theme) {
    final dev = _device;
    if (dev == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.devices_other, size: 20, color: theme.colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa có thiết bị nào được ghép nối cho trẻ.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasBattery = dev.batteryPercentage != null;
    final isLow = dev.isLowBattery;
    final isCharging = dev.isCharging == true;
    final isStale = dev.isBatteryStale;

    IconData batteryIcon;
    Color batteryColor;
    if (isCharging) {
      batteryIcon = Icons.battery_charging_full;
      batteryColor = Colors.amber.shade800;
    } else if (!hasBattery) {
      batteryIcon = Icons.battery_unknown;
      batteryColor = theme.colorScheme.outline;
    } else if (isLow) {
      batteryIcon = Icons.battery_alert;
      batteryColor = Colors.red.shade700;
    } else if (dev.batteryPercentage! >= 80) {
      batteryIcon = Icons.battery_full;
      batteryColor = Colors.green.shade700;
    } else if (dev.batteryPercentage! >= 50) {
      batteryIcon = Icons.battery_5_bar;
      batteryColor = Colors.green.shade600;
    } else {
      batteryIcon = Icons.battery_3_bar;
      batteryColor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLow
            ? Colors.red.shade50
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow ? Colors.red.shade300 : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(batteryIcon, size: 24, color: batteryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pin thiết bị: ${hasBattery ? dev.batteryFormatted : "Chưa có dữ liệu"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isLow ? Colors.red.shade900 : null,
                      ),
                    ),
                    Text(
                      'Thiết bị: ${dev.deviceName} • ${hasBattery ? "Cập nhật: ${dev.batteryTimeAgo}" : "Đang chờ đồng bộ"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCharging)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 14, color: Colors.amber.shade900),
                      Text(
                        'Đang sạc',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Low battery warning alert
          if (isLow) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cảnh báo: Pin thiết bị dưới 20% (${dev.batteryPercentage}%). Hãy nhắc bé cắm sạc!',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stale battery indicator
          if (hasBattery && isStale && !isLow) ...[
            const SizedBox(height: 6),
            Text(
              'Dữ liệu pin cập nhật hơn 1 giờ trước.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefreshRequestSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: _isRequestingRefresh
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.satellite_alt_outlined, size: 18),
          label: Text(
            _isRequestingRefresh ? 'Đang gửi yêu cầu vị trí...' : 'Yêu cầu vị trí mới',
          ),
          onPressed: _isRequestingRefresh ? null : _requestLocationRefresh,
        ),

        // Live status banner
        if (_refreshStatusMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getRefreshStatusBackgroundColor(theme),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getRefreshStatusBorderColor(theme)),
            ),
            child: Row(
              children: [
                _getRefreshStatusIcon(theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _refreshStatusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getRefreshStatusTextColor(theme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _getRefreshStatusIcon(ThemeData theme) {
    if (_isRequestingRefresh) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final req = _refreshRequestModel;
    if (req != null && req.isCompleted) {
      return const Icon(Icons.check_circle, size: 18, color: Colors.green);
    }
    if (req != null && (req.isFailed || req.isExpired)) {
      return Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error);
    }
    return Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary);
  }

  Color _getRefreshStatusBackgroundColor(ThemeData theme) {
    final req = _refreshRequestModel;
    if (req != null && req.isCompleted) {
      return Colors.green.shade50;
    }
    if (req != null && (req.isFailed || req.isExpired)) {
      return Colors.red.shade50;
    }
    if (_isRequestingRefresh) {
      return Colors.blue.shade50;
    }
    return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
  }

  Color _getRefreshStatusBorderColor(ThemeData theme) {
    final req = _refreshRequestModel;
    if (req != null && req.isCompleted) {
      return Colors.green.shade300;
    }
    if (req != null && (req.isFailed || req.isExpired)) {
      return Colors.red.shade300;
    }
    if (_isRequestingRefresh) {
      return Colors.blue.shade300;
    }
    return theme.colorScheme.outlineVariant;
  }

  Color _getRefreshStatusTextColor(ThemeData theme) {
    final req = _refreshRequestModel;
    if (req != null && req.isCompleted) {
      return Colors.green.shade900;
    }
    if (req != null && (req.isFailed || req.isExpired)) {
      return Colors.red.shade900;
    }
    if (_isRequestingRefresh) {
      return Colors.blue.shade900;
    }
    return theme.colorScheme.onSurfaceVariant;
  }

  Widget _buildLocationSection(ThemeData theme) {
    final loc = _location;

    if (loc == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Chưa có dữ liệu vị trí',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thiết bị của bé chưa gửi bản ghi GPS nào lên hệ thống. '
              'Vui lòng nhấn "Cập nhật vị trí" trên thiết bị của trẻ hoặc bấm "Yêu cầu vị trí mới" ở trên.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Kiểm tra lại'),
              onPressed: () => _fetchData(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loc.isStale) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_filled, size: 18, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dữ liệu vị trí đã cũ (${loc.relativeTimeFormatted}). Thiết bị có thể đã tắt hoặc mất GPS.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Coordinates Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.place,
                iconColor: Colors.red,
                label: 'Tọa độ GPS',
                value: loc.coordinatesFormatted,
                isBold: true,
              ),
              const Divider(height: 18),
              _buildInfoRow(
                icon: Icons.gps_fixed,
                iconColor: Colors.blue,
                label: 'Độ chính xác',
                value: loc.accuracyFormatted,
              ),
              if (loc.deviceName.isNotEmpty) ...[
                const Divider(height: 18),
                _buildInfoRow(
                  icon: Icons.smartphone,
                  iconColor: Colors.purple,
                  label: 'Thiết bị gửi',
                  value: loc.deviceName,
                ),
              ],
              const Divider(height: 18),
              _buildInfoRow(
                icon: Icons.schedule,
                iconColor: Colors.orange,
                label: 'Ghi nhận lúc',
                value: '${loc.localTimestampFormatted}\n(${loc.relativeTimeFormatted})',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:geolocator/geolocator.dart';

/// Abstract contract for device GPS and location hardware services.
/// Allows clean substitution with test doubles/mocks during unit and widget tests.
abstract class IGpsService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> openAppSettings();
  Future<Position> getCurrentPosition();
}

/// Concrete implementation utilizing the official `geolocator` plugin.
class GeolocatorGpsService implements IGpsService {
  const GeolocatorGpsService();

  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }
}


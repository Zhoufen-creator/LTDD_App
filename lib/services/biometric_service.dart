import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Abstract contract for device biometric authentication (Fingerprint, Face, Iris, etc.).
/// Enables mock substitution during unit and widget tests.
abstract class IBiometricService {
  /// Whether the device hardware supports biometrics or device-level authentication.
  Future<bool> isDeviceSupported();

  /// Whether biometric sensors are available and biometrics are currently enrolled.
  Future<bool> canCheckBiometrics();

  /// Retrieves the list of enrolled biometric types (fingerprint, face, iris, etc.).
  Future<List<BiometricType>> getAvailableBiometrics();

  /// Invokes the system biometric prompt.
  /// Returns `true` if authentication succeeded, `false` on cancellation, failure, or refusal.
  Future<bool> authenticate({required String localizedReason});
}

/// Concrete implementation utilizing the official `local_auth` Flutter plugin.
class BiometricService implements IBiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    } catch (_) {
      return <BiometricType>[];
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      // User cancelled, passcode not set, biometric sensor busy, or NotEnrolled
      return false;
    } catch (_) {
      return false;
    }
  }
}

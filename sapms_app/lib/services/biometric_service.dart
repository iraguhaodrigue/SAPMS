import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Result of a biometric verification attempt.
/// Keeping this as an explicit class (rather than just a bool) so the
/// caller can show a specific, honest message instead of a generic
/// "failed" — important during testing and demoing on real devices.
class BiometricResult {
  final bool success;
  final String message;
  const BiometricResult(this.success, this.message);
}

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether this device has biometric hardware AND at least one
  /// fingerprint/face enrolled. Check this before showing any
  /// "Verify Fingerprint" button so we can fall back gracefully.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Returns the list of enrolled biometric types (fingerprint, face, etc.)
  /// Useful for debugging on a real device during Step 1 testing.
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Prompts the OS-level biometric dialog. [reason] is shown to the user
  /// inside the system prompt (Android requires a non-empty reason).
  Future<BiometricResult> authenticate({
    required String reason,
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) {
        return const BiometricResult(
          false,
          'No fingerprint/biometric enrolled on this device. '
          'Add one in phone Settings > Security, or use a device that supports it.',
        );
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true, // don't fall back to PIN/pattern — we want a real fingerprint check
          stickyAuth: true,    // survive brief app backgrounding (e.g. notification pull-down)
        ),
      );

      if (didAuthenticate) {
        return const BiometricResult(true, 'Verified');
      }
      return const BiometricResult(false, 'Fingerprint not recognized. Try again.');
    } on PlatformException catch (e) {
      // Map the common local_auth error codes to plain messages —
      // useful both for the teacher and for you while testing.
      switch (e.code) {
        case auth_error.notAvailable:
          return const BiometricResult(false, 'Biometric hardware not available.');
        case auth_error.notEnrolled:
          return const BiometricResult(false, 'No fingerprint enrolled on this device.');
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return const BiometricResult(
              false, 'Too many failed attempts. Try again later or unlock with device PIN.');
        default:
          return BiometricResult(false, 'Authentication error: ${e.message ?? e.code}');
      }
    } catch (e) {
      return BiometricResult(false, 'Unexpected error: $e');
    }
  }
}

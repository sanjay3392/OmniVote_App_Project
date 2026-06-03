import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart' hide BiometricType;
import 'package:local_auth_android/local_auth_android.dart' hide BiometricType;
import 'package:local_auth_platform_interface/types/biometric_type.dart' as auth;
import '../models/models.dart';
import '../constants/app_constants.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // Check if biometric authentication is available
  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types
  Future<List<auth.BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      final List<auth.BiometricType> availableBiometrics =
      await _localAuth.getAvailableBiometrics();
      return availableBiometrics;
    } catch (e) {
      return [];
    }
  }

  // Authenticate using biometrics.
  // On web, always returns success: false — callers must handle this gracefully.
  Future<BiometricAuthResult> authenticate({
    String reason = AppStrings.biometricReason,
  }) async {
    if (kIsWeb) {
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Biometric authentication is not supported on web',
      );
    }

    try {
      final bool canAuthenticateWithBiometrics = await canCheckBiometrics();
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'Biometric authentication not available on this device',
        );
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'OmniVote Authentication',
            cancelButton: 'Cancel',
            biometricHint: 'Verify your identity',
            biometricNotRecognized: 'Not recognized. Try again.',
            biometricSuccess: 'Authentication successful',
          ),
        ],
      );

      if (didAuthenticate) {
        final availableBiometrics = await getAvailableBiometrics();
        BiometricType? type;

        if (availableBiometrics.contains(auth.BiometricType.face)) {
          type = BiometricType.face;
        } else if (availableBiometrics
            .contains(auth.BiometricType.fingerprint)) {
          type = BiometricType.fingerprint;
        } else if (availableBiometrics.contains(auth.BiometricType.iris)) {
          type = BiometricType.iris;
        }

        return BiometricAuthResult(success: true, type: type);
      } else {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'Authentication cancelled or failed',
        );
      }
    } on PlatformException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'NotAvailable':
          errorMessage = 'Biometric authentication is not available';
          break;
        case 'NotEnrolled':
          errorMessage = 'No biometric credentials enrolled';
          break;
        case 'LockedOut':
          errorMessage = 'Too many failed attempts. Please try again later';
          break;
        case 'PermanentlyLockedOut':
          errorMessage = 'Biometric authentication permanently locked';
          break;
        default:
          errorMessage = e.message ?? AppStrings.errorBiometric;
      }
      return BiometricAuthResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  // Stop authentication
  Future<void> stopAuthentication() async {
    if (kIsWeb) return;
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Ignore errors when stopping authentication
    }
  }

  // Get biometric type display name
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scan';
      case BiometricType.none:
        return 'None';
    }
  }

  // Check if strong biometric is available (Face ID or Fingerprint)
  Future<bool> hasStrongBiometric() async {
    if (kIsWeb) return false;
    final availableBiometrics = await getAvailableBiometrics();
    return availableBiometrics.contains(auth.BiometricType.face) ||
        availableBiometrics.contains(auth.BiometricType.fingerprint);
  }
}
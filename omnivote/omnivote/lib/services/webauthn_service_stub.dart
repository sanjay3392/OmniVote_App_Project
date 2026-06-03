/// Stub implementation for non-web platforms (Android, iOS, Desktop).
/// All methods return safe defaults — biometric is handled by BiometricService instead.
class WebAuthnService {
  static Future<bool> isAvailable() async => false;

  static Future<Map<String, dynamic>> register({
    required String challenge,
    required String userId,
    required String userName,
    required String rpId,
  }) async => {'success': false, 'error': 'WebAuthn not available on this platform'};

  static Future<Map<String, dynamic>> authenticate({
    required String challenge,
    required String credentialId,
    required String rpId,
  }) async => {'success': false, 'error': 'WebAuthn not available on this platform'};
}
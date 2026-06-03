/// WebAuthn service — conditionally imports web or stub implementation.
/// On Android/iOS: returns safe stubs (biometric handled by BiometricService).
/// On Flutter Web: uses browser WebAuthn API via webauthn_bridge.js.
export 'webauthn_service_stub.dart'
if (dart.library.js_util) 'webauthn_service_web.dart';
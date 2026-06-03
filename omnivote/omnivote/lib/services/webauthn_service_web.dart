import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Modern WebAuthn implementation for Flutter Web.
class WebAuthnService {

  static JSObject? get _bridge {
    // Accesses window.OmniVoteWebAuthn
    return globalContext.getProperty('OmniVoteWebAuthn' as JSString) as JSObject?;
  }

  static Future<bool> isAvailable() async {
    try {
      final bridge = _bridge;
      if (bridge == null) return false;

      // Calls bridge.isAvailable()
      final JSPromise promise = bridge.callMethod('isAvailable' as JSString);
      final JSAny? result = await promise.toDart;
      return (result as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> register({
    required String challenge,
    required String userId,
    required String userName,
    required String rpId,
  }) async {
    try {
      final bridge = _bridge;
      if (bridge == null) throw 'Bridge not found';

      final opts = {
        'challenge': challenge,
        'userId': userId,
        'userName': userName,
        'rpName': 'OmniVote',
        'rpId': rpId,
      }.jsify() as JSObject;

      final JSPromise promise = bridge.callMethod('register' as JSString, opts);
      final JSAny? result = await promise.toDart;
      return _toMap(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> authenticate({
    required String challenge,
    required String credentialId,
    required String rpId,
  }) async {
    try {
      final bridge = _bridge;
      if (bridge == null) throw 'Bridge not found';

      final opts = {
        'challenge': challenge,
        'credentialId': credentialId,
        'rpId': rpId,
      }.jsify() as JSObject;

      final JSPromise promise = bridge.callMethod('authenticate' as JSString, opts);
      final JSAny? result = await promise.toDart;
      return _toMap(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> _toMap(JSAny? jsObj) {
    if (jsObj == null) return {'success': false, 'error': 'No response'};
    try {
      // Use the global JSON.stringify
      final jsonGlobal = globalContext.getProperty('JSON' as JSString) as JSObject;
      final JSString str = jsonGlobal.callMethod('stringify' as JSString, jsObj) as JSString;
      return json.decode(str.toDart) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'error': 'Failed to parse response'};
    }
  }
}
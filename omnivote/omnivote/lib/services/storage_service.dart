// ═══════════════════════════════════════════════════════════════
// PART 1 — storage_service.dart  (replace your existing file)
// Adds token storage methods required by ApiClient.
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class StorageService {
  static const String _keyUser = 'user';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyPublicKey = 'public_key';
  static const String _keyPrivateKey = 'private_key';
  static const String _keyDID = 'did';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyToken = 'auth_token'; // NEW

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  String? _cachedToken; // in-memory so ApiClient can read sync

  StorageService(this._prefs, this._secureStorage);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final svc = StorageService(prefs, secureStorage);
    svc._cachedToken = await secureStorage.read(key: _keyToken);
    return svc;
  }

  // Token
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _secureStorage.write(key: _keyToken, value: token);
  }
  Future<String?> getToken() async {
    _cachedToken ??= await _secureStorage.read(key: _keyToken);
    return _cachedToken;
  }
  String? getCachedToken() => _cachedToken;
  Future<void> clearToken() async {
    _cachedToken = null;
    await _secureStorage.delete(key: _keyToken);
  }

  // User
  Future<void> saveUser(User user) async =>
      await _prefs.setString(_keyUser, jsonEncode(user.toJson()));
  User? getUser() {
    final j = _prefs.getString(_keyUser);
    return j == null ? null : User.fromJson(jsonDecode(j) as Map<String, dynamic>);
  }
  Future<void> clearUser() async => await _prefs.remove(_keyUser);

  // Biometric
  Future<void> setBiometricEnabled(bool v) async => await _prefs.setBool(_keyBiometricEnabled, v);
  bool isBiometricEnabled() => _prefs.getBool(_keyBiometricEnabled) ?? false;

  // Keys
  Future<void> saveKeys({required String publicKey, required String privateKey}) async {
    await _secureStorage.write(key: _keyPublicKey, value: publicKey);
    await _secureStorage.write(key: _keyPrivateKey, value: privateKey);
  }
  Future<String?> getPublicKey() async => await _secureStorage.read(key: _keyPublicKey);
  Future<String?> getPrivateKey() async => await _secureStorage.read(key: _keyPrivateKey);
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _keyPublicKey);
    await _secureStorage.delete(key: _keyPrivateKey);
  }

  // DID
  Future<void> saveDID(String did) async => await _secureStorage.write(key: _keyDID, value: did);
  Future<String?> getDID() async => await _secureStorage.read(key: _keyDID);
  Future<void> clearDID() async => await _secureStorage.delete(key: _keyDID);

  // First launch
  bool isFirstLaunch() => _prefs.getBool(_keyFirstLaunch) ?? true;
  Future<void> setFirstLaunchComplete() async => await _prefs.setBool(_keyFirstLaunch, false);

  // Vote history
  Future<void> saveVoteHistory(List<String> ids) async => await _prefs.setStringList('vote_history', ids);
  List<String> getVoteHistory() => _prefs.getStringList('vote_history') ?? [];
  Future<void> addToVoteHistory(String id) async {
    final h = getVoteHistory()..add(id);
    await saveVoteHistory(h);
  }

  Future<void> clearAll() async {
    _cachedToken = null;
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }
}

// ═══════════════════════════════════════════════════════════════
// PART 2 — Add these extensions to models.dart
// They bridge the backend _id field names to your Dart models.
// ═══════════════════════════════════════════════════════════════

extension UserApiJson on User {
  static User fromApiJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id']) as String,
      did: json['did'] as String,
      publicKey: json['publicKey'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'] as String)
          : null,
    );
  }
}

extension ElectionApiJson on Election {
  static Election fromApiJson(Map<String, dynamic> json) {
    return Election(
      id: (json['_id'] ?? json['id']) as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      organizationName: json['organizationName'] as String? ?? '',
      type: ElectionType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type'],
        orElse: () => ElectionType.general,
      ),
      status: ElectionStatus.values.firstWhere(
            (e) => e.toString().split('.').last == json['status'],
        orElse: () => ElectionStatus.pending,
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      candidates: (json['candidates'] as List)
          .map((c) => _candidateFromApiJson(c as Map<String, dynamic>))
          .toList(),
      totalVotes: json['totalVotes'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  static Candidate _candidateFromApiJson(Map<String, dynamic> json) {
    return Candidate(
      id: (json['_id'] ?? json['id']) as String,
      name: json['name'] as String,
      party: json['party'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      voteCount: json['voteCount'] as int? ?? 0,
    );
  }
}
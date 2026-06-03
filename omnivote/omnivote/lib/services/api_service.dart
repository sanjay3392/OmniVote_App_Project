import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/storage_service.dart';

// ─────────────────────────────────────────────
// CONFIGURATION — Backend is on PORT 3000
//
// EMULATOR (default):
//   _deviceUrl = 'http://10.0.2.2:3000'
//   10.0.2.2 is Android emulator's alias for your PC's localhost
//
// PHYSICAL PHONE:
//   1. Find your PC's local IP:
//      Windows → run `ipconfig` → look for IPv4 Address (e.g. 192.168.1.5)
//      Mac/Linux → run `ifconfig` → look for inet (e.g. 192.168.1.5)
//   2. Change _deviceUrl below to:
//      'http://192.168.1.5:3000'   ← use YOUR actual IP
//   3. Phone and PC must be on the SAME WiFi network
//
// WEB BROWSER:
//   _webUrl = 'http://localhost:3000'  (no change needed)
// ─────────────────────────────────────────────
class ApiConfig {
  static const String _webUrl = 'http://localhost:3000';

  // ↓↓ PHYSICAL PHONE: replace with YOUR PC's local IP ↓↓
  // Step 1: On your PC, open CMD and run: ipconfig
  // Step 2: Find "IPv4 Address" e.g. 192.168.1.5
  // Step 3: Replace YOUR_PC_IP below with that number
  static const String _deviceUrl = 'http://localhost:3000';
  // e.g. → 'http://192.168.1.5:3000'

  static String get baseUrl => kIsWeb ? _webUrl : _deviceUrl;
  static const Duration timeout = Duration(seconds: 15);
}

// ─────────────────────────────────────────────
// EXCEPTIONS
// ─────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// ─────────────────────────────────────────────
// BASE HTTP CLIENT
// Handles auth headers, error parsing, and timeout.
// ─────────────────────────────────────────────
class ApiClient {
  final StorageService _storage;

  ApiClient(this._storage);

  Future<String?> _getToken() async {
    return await _storage.getToken();
  }

  Map<String, String> _headers({bool requiresAuth = true, String? token}) {
    final headers = {'Content-Type': 'application/json'};
    final t = token ?? _storage.getCachedToken();
    if (requiresAuth && t != null) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(
      String path, {
        bool requiresAuth = true,
      }) async {
    final token = requiresAuth ? await _getToken() : null;
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http
        .get(uri, headers: _headers(requiresAuth: requiresAuth, token: token))
        .timeout(ApiConfig.timeout);

    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body, {
        bool requiresAuth = true,
      }) async {
    final token = requiresAuth ? await _getToken() : null;
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http
        .post(
      uri,
      headers: _headers(requiresAuth: requiresAuth, token: token),
      body: jsonEncode(body),
    )
        .timeout(ApiConfig.timeout);

    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> put(
      String path,
      Map<String, dynamic> body, {
        bool requiresAuth = true,
      }) async {
    final token = requiresAuth ? await _getToken() : null;
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http
        .put(
      uri,
      headers: _headers(requiresAuth: requiresAuth, token: token),
      body: jsonEncode(body),
    )
        .timeout(ApiConfig.timeout);

    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    late Map<String, dynamic> body;

    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid server response', statusCode: response.statusCode);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body['message'] as String? ?? 'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

// ─────────────────────────────────────────────
// AUTH SERVICE
// Connects to /api/auth/*
// ─────────────────────────────────────────────
class AuthApiService {
  final ApiClient _client;
  final StorageService _storage;

  AuthApiService(this._client, this._storage);

  /// Register a new user (device-first: no email/password required).
  /// Returns the User and saves the JWT + private key locally.
  Future<User> register({
    String? name,
    String? aadharNumber,
    String? voterIdNumber,
    String? email,
    String? deviceId,
    String? devicePlatform,
  }) async {
    final response = await _client.post(
      '/api/auth/register',
      {
        if (name != null) 'name': name,
        if (aadharNumber != null) 'aadharNumber': aadharNumber,
        if (voterIdNumber != null) 'voterIdNumber': voterIdNumber,
        if (email != null) 'email': email,
        if (deviceId != null) 'deviceId': deviceId,
        if (devicePlatform != null) 'devicePlatform': devicePlatform,
      },
      requiresAuth: false,
    );

    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final privateKey = data['privateKey'] as String?;
    final user = User.fromApiJson(data['user'] as Map<String, dynamic>);

    // Persist token, DID, keys
    await _storage.saveToken(token);
    await _storage.saveDID(user.did);
    if (privateKey != null) {
      await _storage.saveKeys(
        publicKey: user.publicKey,
        privateKey: privateKey,
      );
    }
    await _storage.saveUser(user);

    return user;
  }

  /// Login with DID + biometric signature, or email + password.
  Future<User> login({
    String? voterIdNumber,
    String? did,
    String? email,
    String? password,
  }) async {
    final response = await _client.post(
      '/api/auth/login',
      {
        if (voterIdNumber != null) 'voterIdNumber': voterIdNumber,
        if (did != null) 'did': did,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
      },
      requiresAuth: false,
    );

    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = User.fromApiJson(data['user'] as Map<String, dynamic>);

    await _storage.saveToken(token);
    await _storage.saveUser(user);

    return user;
  }

  /// Dedicated biometric login — backend enforces biometricEnabled check.
  Future<User> biometricLogin({required String voterIdNumber}) async {
    final response = await _client.post(
      '/api/auth/biometric/login',
      {'voterIdNumber': voterIdNumber},
      requiresAuth: false,
    );
    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = User.fromApiJson(data['user'] as Map<String, dynamic>);
    await _storage.saveToken(token);
    await _storage.saveUser(user);
    return user;
  }

  /// Enable biometric on the server (call after local biometric succeeds).
  Future<void> enableBiometric(String biometricPublicKey) async {
    await _client.post(
      '/api/auth/biometric/enable',
      {'biometricPublicKey': biometricPublicKey},
    );
  }

  /// Get the current authenticated user from the server.
  Future<User> getMe() async {
    final response = await _client.get('/api/auth/me');
    final user = User.fromApiJson(
      (response['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
    await _storage.saveUser(user);
    return user;
  }


  // ── WebAuthn (Web Fingerprint) ────────────────────────────────────────────

  /// Get registration challenge from server
  Future<Map<String, dynamic>> webAuthnRegisterChallenge() async {
    final response = await _client.post('/api/auth/webauthn/register/challenge', {});
    return response['data'] as Map<String, dynamic>;
  }

  /// Verify registration and store credential on server
  Future<void> webAuthnRegisterVerify({
    required String credentialId,
    required String publicKey,
    required String clientDataJSON,
    required String attestationObject,
  }) async {
    await _client.post('/api/auth/webauthn/register/verify', {
      'credentialId': credentialId,
      'publicKey': publicKey,
      'clientDataJSON': clientDataJSON,
      'attestationObject': attestationObject,
    });
  }

  /// Get login challenge for WebAuthn
  Future<Map<String, dynamic>> webAuthnLoginChallenge({required String voterIdNumber}) async {
    final response = await _client.post(
      '/api/auth/webauthn/login/challenge',
      {'voterIdNumber': voterIdNumber},
      requiresAuth: false,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Verify login assertion and get token
  Future<User> webAuthnLoginVerify({
    required String voterIdNumber,
    required String credentialId,
    required String clientDataJSON,
    required String signature,
  }) async {
    final response = await _client.post(
      '/api/auth/webauthn/login/verify',
      {
        'voterIdNumber': voterIdNumber,
        'credentialId': credentialId,
        'clientDataJSON': clientDataJSON,
        'signature': signature,
      },
      requiresAuth: false,
    );
    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = User.fromApiJson(data['user'] as Map<String, dynamic>);
    await _storage.saveToken(token);
    await _storage.saveUser(user);
    return user;
  }

  /// Get vote challenge for WebAuthn
  Future<Map<String, dynamic>> webAuthnVoteChallenge() async {
    final response = await _client.post('/api/auth/webauthn/vote/challenge', {});
    return response['data'] as Map<String, dynamic>;
  }

  /// Verify vote assertion
  Future<void> webAuthnVoteVerify({
    required String credentialId,
    required String clientDataJSON,
    required String signature,
  }) async {
    await _client.post('/api/auth/webauthn/vote/verify', {
      'credentialId': credentialId,
      'clientDataJSON': clientDataJSON,
      'signature': signature,
    });
  }

  /// Refresh the JWT token.
  Future<String> refreshToken() async {
    final response = await _client.post('/api/auth/refresh', {});
    final token = (response['data'] as Map<String, dynamic>)['token'] as String;
    await _storage.saveToken(token);
    return token;
  }
}

// ─────────────────────────────────────────────
// ELECTIONS SERVICE
// Connects to /api/elections/*
// ─────────────────────────────────────────────
class ElectionsApiService {
  final ApiClient _client;

  ElectionsApiService(this._client);

  /// Fetch all public elections. Filter by [status] or [type] if needed.
  Future<ElectionListResult> getElections({
    String? status, // 'pending' | 'active' | 'closed'
    String? type,   // 'general' | 'presidential' etc.
    int page = 1,
    int limit = 20,
  }) async {
    final params = StringBuffer('/api/elections?page=$page&limit=$limit');
    if (status != null) params.write('&status=$status');
    if (type != null) params.write('&type=$type');

    final response = await _client.get(params.toString(), requiresAuth: false);
    final data = response['data'] as Map<String, dynamic>;

    final elections = (data['elections'] as List)
        .map((e) => Election.fromApiJson(e as Map<String, dynamic>))
        .toList();

    final pagination = data['pagination'] as Map<String, dynamic>;

    return ElectionListResult(
      elections: elections,
      total: pagination['total'] as int,
      page: pagination['page'] as int,
      pages: pagination['pages'] as int,
    );
  }

  /// Fetch a single election by ID.
  Future<Election> getElection(String id) async {
    final response = await _client.get('/api/elections/$id', requiresAuth: false);
    return Election.fromApiJson(
      (response['data'] as Map<String, dynamic>)['election'] as Map<String, dynamic>,
    );
  }

  /// Get live results for an election.
  Future<ElectionResults> getResults(String id) async {
    final response = await _client.get('/api/elections/$id/results', requiresAuth: false);
    return ElectionResults.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Check if the logged-in user is eligible to vote.
  Future<EligibilityResult> checkEligibility(String electionId) async {
    final response = await _client.post(
      '/api/elections/$electionId/check-eligibility',
      {},
    );
    return EligibilityResult.fromJson(response['data'] as Map<String, dynamic>);
  }
}

// ─────────────────────────────────────────────
// VOTES SERVICE
// Connects to /api/votes/*
// ─────────────────────────────────────────────
class VotesApiService {
  final ApiClient _client;

  VotesApiService(this._client);

  /// Cast a vote. [biometricVerified] must be true after local biometric auth.
  Future<VoteReceiptData> castVote({
    required String electionId,
    required String candidateId,
    required bool biometricVerified,
  }) async {
    final response = await _client.post(
      '/api/votes/cast',
      {
        'electionId': electionId,
        'candidateId': candidateId,
        'biometricVerified': biometricVerified,
      },
    );

    return VoteReceiptData.fromJson(
      (response['data'] as Map<String, dynamic>)['voteReceipt'] as Map<String, dynamic>,
    );
  }

  /// Get a receipt for a specific transaction hash.
  Future<VoteReceiptData> getReceipt(String transactionHash) async {
    final response = await _client.get('/api/votes/receipt/$transactionHash');
    return VoteReceiptData.fromJson(
      (response['data'] as Map<String, dynamic>)['vote'] as Map<String, dynamic>,
    );
  }

  /// Publicly verify a vote by transaction hash (no auth needed).
  Future<VoteVerification> verifyVote(String transactionHash) async {
    final response = await _client.get(
      '/api/votes/verify/$transactionHash',
      requiresAuth: false,
    );
    return VoteVerification.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Get the current user's full vote history.
  Future<List<VoteHistoryItem>> getMyVotes() async {
    final response = await _client.get('/api/votes/my-votes');
    final raw = (response['data'] as Map<String, dynamic>)['votes'] as List?;
    return (raw ?? [])
        .map((v) => VoteHistoryItem.fromJson(v as Map<String, dynamic>))
        .toList();
  }
}

// ─────────────────────────────────────────────
// USERS SERVICE
// Connects to /api/users/*
// ─────────────────────────────────────────────
class UsersApiService {
  final ApiClient _client;
  final StorageService _storage;

  UsersApiService(this._client, this._storage);

  /// Get the current user's profile.
  Future<User> getProfile() async {
    final response = await _client.get('/api/users/profile');
    final user = User.fromApiJson(
      (response['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
    await _storage.saveUser(user);
    return user;
  }

  /// Update name or email.
  Future<User> updateProfile({String? name, String? email}) async {
    final response = await _client.put('/api/users/profile', {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
    final user = User.fromApiJson(
      (response['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
    await _storage.saveUser(user);
    return user;
  }

  /// Change password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.put('/api/users/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}

// ─────────────────────────────────────────────
// FACADE — single access point for all services
// ─────────────────────────────────────────────
class OmniVoteApi {
  late final AuthApiService auth;
  late final ElectionsApiService elections;
  late final VotesApiService votes;
  late final UsersApiService users;

  OmniVoteApi._internal(StorageService storage) {
    final client = ApiClient(storage);
    auth = AuthApiService(client, storage);
    elections = ElectionsApiService(client);
    votes = VotesApiService(client);
    users = UsersApiService(client, storage);
  }

  static OmniVoteApi? _instance;

  static Future<OmniVoteApi> init() async {
    final storage = await StorageService.init();
    _instance = OmniVoteApi._internal(storage);
    return _instance!;
  }

  static OmniVoteApi get instance {
    assert(_instance != null, 'Call OmniVoteApi.init() first');
    return _instance!;
  }
}

// ─────────────────────────────────────────────
// RESPONSE DATA MODELS
// (separate from domain models — maps raw API JSON)
// ─────────────────────────────────────────────

class ElectionListResult {
  final List<Election> elections;
  final int total;
  final int page;
  final int pages;

  ElectionListResult({
    required this.elections,
    required this.total,
    required this.page,
    required this.pages,
  });
}

class ElectionResults {
  final String electionId;
  final String title;
  final String status;
  final int totalVotes;
  final List<CandidateResult> results;
  final CandidateResult? winner;

  ElectionResults({
    required this.electionId,
    required this.title,
    required this.status,
    required this.totalVotes,
    required this.results,
    this.winner,
  });

  factory ElectionResults.fromJson(Map<String, dynamic> json) {
    final resultsList = (json['results'] as List)
        .map((r) => CandidateResult.fromJson(r as Map<String, dynamic>))
        .toList();

    return ElectionResults(
      electionId: json['electionId'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      totalVotes: json['totalVotes'] as int? ?? 0,
      results: resultsList,
      winner: json['winner'] != null
          ? CandidateResult.fromJson(json['winner'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CandidateResult {
  final String candidateId;
  final String name;
  final String? party;
  final int voteCount;
  final String percentage;

  CandidateResult({
    required this.candidateId,
    required this.name,
    this.party,
    required this.voteCount,
    required this.percentage,
  });

  factory CandidateResult.fromJson(Map<String, dynamic> json) => CandidateResult(
    candidateId: json['candidateId'] as String,
    name: json['name'] as String,
    party: json['party'] as String?,
    voteCount: json['voteCount'] as int,
    percentage: json['percentage'] as String,
  );
}

class EligibilityResult {
  final bool eligible;
  final String? reason;
  final String? transactionHash; // set when already voted

  EligibilityResult({required this.eligible, this.reason, this.transactionHash});

  factory EligibilityResult.fromJson(Map<String, dynamic> json) => EligibilityResult(
    eligible: json['eligible'] as bool,
    reason: json['reason'] as String?,
    transactionHash: (json['voteReceipt'] as Map<String, dynamic>?)?['transactionHash']
    as String?,
  );
}

class VoteReceiptData {
  final String id;
  final String transactionHash;
  final String status;
  final DateTime timestamp;
  final String? zkProof;
  final int? blockNumber;
  final String? network;
  final String? fee;
  final String? candidateName;

  VoteReceiptData({
    required this.id,
    required this.transactionHash,
    required this.status,
    required this.timestamp,
    this.zkProof,
    this.blockNumber,
    this.network,
    this.fee,
    this.candidateName,
  });

  factory VoteReceiptData.fromJson(Map<String, dynamic> json) => VoteReceiptData(
    id: json['id'] as String,
    transactionHash: json['transactionHash'] as String,
    status: json['status'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    zkProof: json['zkProof'] as String?,
    blockNumber: json['blockNumber'] as int?,
    network: json['network'] as String?,
    fee: json['fee']?.toString(),
    candidateName: json['candidateName'] as String?,
  );
}

class VoteVerification {
  final bool valid;
  final String transactionHash;
  final String status;
  final DateTime timestamp;
  final bool zkProofPresent;

  VoteVerification({
    required this.valid,
    required this.transactionHash,
    required this.status,
    required this.timestamp,
    required this.zkProofPresent,
  });

  factory VoteVerification.fromJson(Map<String, dynamic> json) => VoteVerification(
    valid: json['valid'] as bool,
    transactionHash: json['transactionHash'] as String,
    status: json['status'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    zkProofPresent: json['zkProofPresent'] as bool,
  );
}

class VoteHistoryItem {
  final String id;
  final String transactionHash;
  final String status;
  final DateTime timestamp;
  final String? network;
  final String? electionTitle;
  final String? electionStatus;

  VoteHistoryItem({
    required this.id,
    required this.transactionHash,
    required this.status,
    required this.timestamp,
    this.network,
    this.electionTitle,
    this.electionStatus,
  });

  factory VoteHistoryItem.fromJson(Map<String, dynamic> json) {
    final election = json['election'] as Map<String, dynamic>?;
    return VoteHistoryItem(
      id: json['id'] as String,
      transactionHash: json['transactionHash'] as String,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      network: json['network'] as String?,
      electionTitle: election?['title'] as String?,
      electionStatus: election?['status'] as String?,
    );
  }
}
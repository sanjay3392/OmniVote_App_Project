class User {
  final String id;
  final String did; // Decentralized Identity
  final String publicKey;
  final String? name;
  final String? email;
  final bool biometricEnabled;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.did,
    required this.publicKey,
    this.name,
    this.email,
    this.biometricEnabled = false,
    this.isVerified = false,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      did: json['did'] as String,
      publicKey: json['publicKey'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'] as String)
          : null,
    );
  }

  factory User.fromApiJson(Map<String, dynamic> json) => User.fromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'did': did,
      'publicKey': publicKey,
      'name': name,
      'email': email,
      'biometricEnabled': biometricEnabled,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? did,
    String? publicKey,
    String? name,
    String? email,
    bool? biometricEnabled,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      did: did ?? this.did,
      publicKey: publicKey ?? this.publicKey,
      name: name ?? this.name,
      email: email ?? this.email,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

class Election {
  final String id;
  final String title;
  final String description;
  final String organizationName;
  final ElectionType type;
  final ElectionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final List<Candidate> candidates;
  final int totalVotes;
  final String? imageUrl;

  Election({
    required this.id,
    required this.title,
    required this.description,
    required this.organizationName,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.candidates,
    this.totalVotes = 0,
    this.imageUrl,
  });

  bool get isActive {
    final now = DateTime.now();
    return status == ElectionStatus.active &&
        now.isAfter(startDate) &&
        now.isBefore(endDate);
  }

  bool get hasEnded {
    return DateTime.now().isAfter(endDate) || status == ElectionStatus.closed;
  }

  factory Election.fromJson(Map<String, dynamic> json) {
    return Election(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      organizationName: json['organizationName'] as String,
      type: ElectionType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => ElectionType.general,
      ),
      status: ElectionStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => ElectionStatus.pending,
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      candidates: (json['candidates'] as List)
          .map((c) => Candidate.fromJson(c as Map<String, dynamic>))
          .toList(),
      totalVotes: json['totalVotes'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  factory Election.fromApiJson(Map<String, dynamic> json) => Election.fromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'organizationName': organizationName,
      'type': type.name,
      'status': status.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'candidates': candidates.map((c) => c.toJson()).toList(),
      'totalVotes': totalVotes,
      'imageUrl': imageUrl,
    };
  }
}

enum ElectionType { general, presidential, parliamentary, corporate, dao, referendum }
enum ElectionStatus { pending, active, closed, cancelled }

class Candidate {
  final String id;
  final String name;
  final String? party;
  final String? description;
  final String? imageUrl;
  final int voteCount;

  Candidate({
    required this.id,
    required this.name,
    this.party,
    this.description,
    this.imageUrl,
    this.voteCount = 0,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      name: json['name'] as String,
      party: json['party'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      voteCount: json['voteCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'party': party,
      'description': description,
      'imageUrl': imageUrl,
      'voteCount': voteCount,
    };
  }
}

class Vote {
  final String id;
  final String electionId;
  final String candidateId;
  final String voterId;
  final String transactionHash;
  final DateTime timestamp;
  final VoteStatus status;
  final String? zkProof;

  Vote({
    required this.id,
    required this.electionId,
    required this.candidateId,
    required this.voterId,
    required this.transactionHash,
    required this.timestamp,
    required this.status,
    this.zkProof,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'] as String,
      electionId: json['electionId'] as String,
      candidateId: json['candidateId'] as String,
      voterId: json['voterId'] as String,
      transactionHash: json['transactionHash'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: VoteStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => VoteStatus.pending,
      ),
      zkProof: json['zkProof'] as String?,
    );
  }

  factory Vote.fromApiJson(Map<String, dynamic> json) => Vote.fromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'electionId': electionId,
      'candidateId': candidateId,
      'voterId': voterId,
      'transactionHash': transactionHash,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'zkProof': zkProof,
    };
  }
}

enum VoteStatus { pending, confirmed, failed, verified }

class VoteReceipt {
  final Vote vote;
  final Election election;
  final Candidate candidate;
  final int confirmationBlocks;

  VoteReceipt({
    required this.vote,
    required this.election,
    required this.candidate,
    this.confirmationBlocks = 0,
  });

  bool get isConfirmed => confirmationBlocks >= 3;

  // Added factory to fix potential missing method errors in ApiService
  factory VoteReceipt.fromJson(Map<String, dynamic> json) {
    return VoteReceipt(
      vote: Vote.fromJson(json['vote'] as Map<String, dynamic>),
      election: Election.fromJson(json['election'] as Map<String, dynamic>),
      candidate: Candidate.fromJson(json['candidate'] as Map<String, dynamic>),
      confirmationBlocks: json['confirmationBlocks'] as int? ?? 0,
    );
  }

  factory VoteReceipt.fromApiJson(Map<String, dynamic> json) => VoteReceipt.fromJson(json);
}

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  final BiometricType? type;

  BiometricAuthResult({
    required this.success,
    this.errorMessage,
    this.type,
  });
}

enum BiometricType { fingerprint, face, iris, none }
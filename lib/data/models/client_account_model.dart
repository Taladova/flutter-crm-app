class ClientAccountModel {
  const ClientAccountModel({
    required this.uid,
    required this.clientId,
    required this.professionalId,
    required this.email,
    required this.displayName,
    this.role = 'client',
    this.projectIds = const [],
    this.sharedClientId = '',
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String clientId;
  final String professionalId;
  final String email;
  final String displayName;
  final String role;
  final List<String> projectIds;

  /// The canonical `shared_clients/{sharedClientId}` doc id this client
  /// conversation lives under. Cached here once resolved so every future
  /// lookup (from any device/session) always lands on the same space
  /// instead of re-deriving it via a fuzzy query.
  final String sharedClientId;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  ClientAccountModel copyWith({
    String? displayName,
    List<String>? projectIds,
    String? sharedClientId,
    DateTime? lastLoginAt,
  }) {
    return ClientAccountModel(
      uid: uid,
      clientId: clientId,
      professionalId: professionalId,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role,
      projectIds: projectIds ?? this.projectIds,
      sharedClientId: sharedClientId ?? this.sharedClientId,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'clientId': clientId,
      'professionalId': professionalId,
      'email': email,
      'displayName': displayName,
      'role': role,
      'projectIds': projectIds,
      'sharedClientId': sharedClientId,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
    };
  }

  factory ClientAccountModel.fromJson(Map<String, dynamic> json) {
    return ClientAccountModel(
      uid: json['uid'] ?? '',
      clientId: json['clientId'] ?? '',
      professionalId: json['professionalId'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      role: json['role'] ?? 'client',
      projectIds: (json['projectIds'] as List?)?.cast<String>() ?? const [],
      sharedClientId: json['sharedClientId'] ?? '',
      createdAt: _dateFromJson(json['createdAt']),
      lastLoginAt: _dateFromJson(json['lastLoginAt']),
    );
  }
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime?;
}

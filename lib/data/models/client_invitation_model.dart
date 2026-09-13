class ClientInvitationModel {
  const ClientInvitationModel({
    required this.token,
    required this.professionalId,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.projectIds,
    this.status = 'active',
    this.clientUid = '',
    this.createdAt,
    this.claimedAt,
  });

  final String token;
  final String professionalId;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final List<String> projectIds;
  final String status;
  final String clientUid;
  final DateTime? createdAt;
  final DateTime? claimedAt;

  bool get isActive => status == 'active';

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'professionalId': professionalId,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'projectIds': projectIds,
      'status': status,
      'clientUid': clientUid,
      'createdAt': createdAt,
      'claimedAt': claimedAt,
    };
  }

  factory ClientInvitationModel.fromJson(Map<String, dynamic> json) {
    return ClientInvitationModel(
      token: json['token'] ?? '',
      professionalId: json['professionalId'] ?? '',
      clientId: json['clientId'] ?? '',
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      projectIds: (json['projectIds'] as List?)?.cast<String>() ?? const [],
      status: json['status'] ?? 'active',
      clientUid: json['clientUid'] ?? '',
      createdAt: _dateFromJson(json['createdAt']),
      claimedAt: _dateFromJson(json['claimedAt']),
    );
  }
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime?;
}

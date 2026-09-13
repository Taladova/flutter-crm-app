class DeliverableModel {
  const DeliverableModel({
    required this.id,
    required this.projectId,
    required this.clientId,
    required this.professionalUid,
    required this.title,
    required this.description,
    required this.kind,
    required this.currentVersion,
    required this.status,
    this.visibleToClient = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String clientId;
  final String professionalUid;
  final String title;
  final String description;
  final String kind;
  final int currentVersion;
  final String status;
  final bool visibleToClient;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAwaitingReview => status == 'awaitingReview';
  bool get isChangesRequested => status == 'changesRequested';
  bool get isApproved => status == 'approved';

  DeliverableModel copyWith({
    String? id,
    String? projectId,
    String? clientId,
    String? professionalUid,
    String? title,
    String? description,
    String? kind,
    int? currentVersion,
    String? status,
    bool? visibleToClient,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliverableModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      clientId: clientId ?? this.clientId,
      professionalUid: professionalUid ?? this.professionalUid,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      currentVersion: currentVersion ?? this.currentVersion,
      status: status ?? this.status,
      visibleToClient: visibleToClient ?? this.visibleToClient,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'clientId': clientId,
      'professionalUid': professionalUid,
      'title': title,
      'description': description,
      'kind': kind,
      'currentVersion': currentVersion,
      'status': status,
      'visibleToClient': visibleToClient,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DeliverableModel.fromJson(Map<String, dynamic> json) {
    return DeliverableModel(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      clientId: json['clientId'] ?? '',
      professionalUid: json['professionalUid'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      kind: json['kind'] ?? 'file',
      currentVersion: json['currentVersion'] ?? 0,
      status: json['status'] ?? 'awaitingReview',
      visibleToClient: json['visibleToClient'] ?? true,
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
    );
  }
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime?;
}

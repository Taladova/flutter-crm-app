class DeliverableVersionModel {
  const DeliverableVersionModel({
    required this.id,
    required this.deliverableId,
    required this.projectId,
    required this.clientId,
    required this.professionalUid,
    required this.versionNumber,
    required this.fileName,
    required this.mimeType,
    required this.uploadedBy,
    required this.status,
    this.storageUrl = '',
    this.externalUrl = '',
    this.clientComment,
    this.uploadedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String deliverableId;
  final String projectId;
  final String clientId;
  final String professionalUid;
  final int versionNumber;
  final String storageUrl;
  final String externalUrl;
  final String fileName;
  final String mimeType;
  final DateTime? uploadedAt;
  final String uploadedBy;
  final String status;
  final String? clientComment;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  String get previewUrl => storageUrl.isNotEmpty ? storageUrl : externalUrl;
  bool get isAwaitingReview => status == 'awaitingReview';
  bool get isChangesRequested => status == 'changesRequested';
  bool get isApproved => status == 'approved';

  DeliverableVersionModel copyWith({
    String? id,
    String? deliverableId,
    String? projectId,
    String? clientId,
    String? professionalUid,
    int? versionNumber,
    String? storageUrl,
    String? externalUrl,
    String? fileName,
    String? mimeType,
    DateTime? uploadedAt,
    String? uploadedBy,
    String? status,
    String? clientComment,
    bool clearClientComment = false,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return DeliverableVersionModel(
      id: id ?? this.id,
      deliverableId: deliverableId ?? this.deliverableId,
      projectId: projectId ?? this.projectId,
      clientId: clientId ?? this.clientId,
      professionalUid: professionalUid ?? this.professionalUid,
      versionNumber: versionNumber ?? this.versionNumber,
      storageUrl: storageUrl ?? this.storageUrl,
      externalUrl: externalUrl ?? this.externalUrl,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      status: status ?? this.status,
      clientComment: clearClientComment
          ? null
          : clientComment ?? this.clientComment,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliverableId': deliverableId,
      'projectId': projectId,
      'clientId': clientId,
      'professionalUid': professionalUid,
      'versionNumber': versionNumber,
      'storageUrl': storageUrl,
      'externalUrl': externalUrl,
      'fileName': fileName,
      'mimeType': mimeType,
      'uploadedAt': uploadedAt,
      'uploadedBy': uploadedBy,
      'status': status,
      'clientComment': clientComment,
      'reviewedAt': reviewedAt,
      'reviewedBy': reviewedBy,
    };
  }

  factory DeliverableVersionModel.fromJson(Map<String, dynamic> json) {
    return DeliverableVersionModel(
      id: json['id'] ?? '',
      deliverableId: json['deliverableId'] ?? '',
      projectId: json['projectId'] ?? '',
      clientId: json['clientId'] ?? '',
      professionalUid: json['professionalUid'] ?? '',
      versionNumber: json['versionNumber'] ?? 1,
      storageUrl: json['storageUrl'] ?? '',
      externalUrl: json['externalUrl'] ?? '',
      fileName: json['fileName'] ?? '',
      mimeType: json['mimeType'] ?? '',
      uploadedAt: _dateFromJson(json['uploadedAt']),
      uploadedBy: json['uploadedBy'] ?? '',
      status: json['status'] ?? 'awaitingReview',
      clientComment: json['clientComment'],
      reviewedAt: _dateFromJson(json['reviewedAt']),
      reviewedBy: json['reviewedBy'],
    );
  }
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime?;
}

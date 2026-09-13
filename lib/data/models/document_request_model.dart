class DocumentRequestModel {
  const DocumentRequestModel({
    required this.id,
    required this.professionalUid,
    required this.clientId,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.required,
    this.dueDate,
    this.uploadedDocumentId,
    this.rejectionComment = '',
    this.clientUid = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String professionalUid;
  final String clientId;
  final String projectId;
  final String title;
  final String description;
  final String status;
  final bool required;
  final DateTime? dueDate;
  final String? uploadedDocumentId;
  final String rejectionComment;
  final String clientUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isRequested => status == 'requested';
  bool get isReceived => status == 'received';
  bool get isValidated => status == 'validated';
  bool get isRejected => status == 'rejected';

  DocumentRequestModel copyWith({
    String? id,
    String? professionalUid,
    String? clientId,
    String? projectId,
    String? title,
    String? description,
    String? status,
    bool? required,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? uploadedDocumentId,
    bool clearUploadedDocumentId = false,
    String? rejectionComment,
    String? clientUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentRequestModel(
      id: id ?? this.id,
      professionalUid: professionalUid ?? this.professionalUid,
      clientId: clientId ?? this.clientId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      required: required ?? this.required,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      uploadedDocumentId: clearUploadedDocumentId
          ? null
          : uploadedDocumentId ?? this.uploadedDocumentId,
      rejectionComment: rejectionComment ?? this.rejectionComment,
      clientUid: clientUid ?? this.clientUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'professionalUid': professionalUid,
      'clientId': clientId,
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status,
      'required': required,
      'dueDate': dueDate,
      'uploadedDocumentId': uploadedDocumentId,
      'rejectionComment': rejectionComment,
      'clientUid': clientUid,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DocumentRequestModel.fromJson(Map<String, dynamic> json) {
    return DocumentRequestModel(
      id: json['id'] ?? '',
      professionalUid: json['professionalUid'] ?? '',
      clientId: json['clientId'] ?? '',
      projectId: json['projectId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'requested',
      required: json['required'] ?? true,
      dueDate: _dateFromJson(json['dueDate']),
      uploadedDocumentId: json['uploadedDocumentId'],
      rejectionComment: json['rejectionComment'] ?? '',
      clientUid: json['clientUid'] ?? '',
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

class DocumentPreparationSummary {
  const DocumentPreparationSummary({
    required this.requiredCount,
    required this.receivedCount,
    required this.missingCount,
  });

  final int requiredCount;
  final int receivedCount;
  final int missingCount;

  double get progress {
    if (requiredCount == 0) return 1;
    return receivedCount / requiredCount;
  }

  factory DocumentPreparationSummary.fromRequests(
    List<DocumentRequestModel> requests,
  ) {
    final requiredRequests = requests.where((request) => request.required);
    final received = requiredRequests.where(
      (request) => request.isReceived || request.isValidated,
    );
    final missing = requiredRequests.where(
      (request) => request.isRequested || request.isRejected,
    );

    return DocumentPreparationSummary(
      requiredCount: requiredRequests.length,
      receivedCount: received.length,
      missingCount: missing.length,
    );
  }
}

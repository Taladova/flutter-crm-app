class DeliverableAnnotationModel {
  const DeliverableAnnotationModel({
    required this.id,
    required this.deliverableVersionId,
    required this.deliverableId,
    required this.projectId,
    required this.professionalUid,
    required this.authorUid,
    required this.x,
    required this.y,
    required this.comment,
    required this.resolved,
    this.pageNumber,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String deliverableVersionId;
  final String deliverableId;
  final String projectId;
  final String professionalUid;
  final String authorUid;
  final double x;
  final double y;
  final int? pageNumber;
  final String comment;
  final DateTime? createdAt;
  final bool resolved;
  final DateTime? resolvedAt;

  DeliverableAnnotationModel copyWith({
    String? id,
    String? deliverableVersionId,
    String? deliverableId,
    String? projectId,
    String? professionalUid,
    String? authorUid,
    double? x,
    double? y,
    int? pageNumber,
    bool clearPageNumber = false,
    String? comment,
    DateTime? createdAt,
    bool? resolved,
    DateTime? resolvedAt,
    bool clearResolvedAt = false,
  }) {
    return DeliverableAnnotationModel(
      id: id ?? this.id,
      deliverableVersionId: deliverableVersionId ?? this.deliverableVersionId,
      deliverableId: deliverableId ?? this.deliverableId,
      projectId: projectId ?? this.projectId,
      professionalUid: professionalUid ?? this.professionalUid,
      authorUid: authorUid ?? this.authorUid,
      x: x ?? this.x,
      y: y ?? this.y,
      pageNumber: clearPageNumber ? null : pageNumber ?? this.pageNumber,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      resolved: resolved ?? this.resolved,
      resolvedAt: clearResolvedAt ? null : resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliverableVersionId': deliverableVersionId,
      'deliverableId': deliverableId,
      'projectId': projectId,
      'professionalUid': professionalUid,
      'authorUid': authorUid,
      'x': x,
      'y': y,
      'pageNumber': pageNumber,
      'comment': comment,
      'createdAt': createdAt,
      'resolved': resolved,
      'resolvedAt': resolvedAt,
    };
  }

  factory DeliverableAnnotationModel.fromJson(Map<String, dynamic> json) {
    return DeliverableAnnotationModel(
      id: json['id'] ?? '',
      deliverableVersionId: json['deliverableVersionId'] ?? '',
      deliverableId: json['deliverableId'] ?? '',
      projectId: json['projectId'] ?? '',
      professionalUid: json['professionalUid'] ?? '',
      authorUid: json['authorUid'] ?? '',
      x: (json['x'] ?? 0).toDouble().clamp(0.0, 1.0),
      y: (json['y'] ?? 0).toDouble().clamp(0.0, 1.0),
      pageNumber: json['pageNumber'],
      comment: json['comment'] ?? '',
      createdAt: _dateFromJson(json['createdAt']),
      resolved: json['resolved'] ?? false,
      resolvedAt: _dateFromJson(json['resolvedAt']),
    );
  }
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime?;
}

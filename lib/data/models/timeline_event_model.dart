class TimelineEventModel {
  const TimelineEventModel({
    required this.id,
    required this.projectId,
    required this.professionalUid,
    required this.title,
    required this.description,
    required this.status,
    required this.order,
    this.visibleToClient = true,
    this.date,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String professionalUid;
  final String title;
  final String description;
  final String status;
  final int order;
  final bool visibleToClient;
  final DateTime? date;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == 'completed';
  bool get isCurrent => status == 'current';
  bool get isUpcoming => status == 'upcoming';

  TimelineEventModel copyWith({
    String? id,
    String? projectId,
    String? professionalUid,
    String? title,
    String? description,
    String? status,
    int? order,
    bool? visibleToClient,
    DateTime? date,
    bool clearDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimelineEventModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      professionalUid: professionalUid ?? this.professionalUid,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      order: order ?? this.order,
      visibleToClient: visibleToClient ?? this.visibleToClient,
      date: clearDate ? null : date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'professionalUid': professionalUid,
      'title': title,
      'description': description,
      'status': status,
      'order': order,
      'visibleToClient': visibleToClient,
      'date': date,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory TimelineEventModel.fromJson(Map<String, dynamic> json) {
    return TimelineEventModel(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      professionalUid: json['professionalUid'] ?? json['professionalId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'upcoming',
      order: json['order'] ?? 0,
      visibleToClient: json['visibleToClient'] ?? true,
      date: _dateFromJson(json['date']),
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

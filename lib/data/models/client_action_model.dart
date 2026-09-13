class ClientActionModel {
  const ClientActionModel({
    required this.id,
    required this.professionalUid,
    required this.projectId,
    required this.clientId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.type,
    required this.priority,
    required this.status,
    this.stageId = '',
    this.visibleToClient = true,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String professionalUid;
  final String projectId;
  final String clientId;
  final String title;
  final String description;
  final String assignedTo;
  final String type;
  final String priority;
  final String status;

  /// Links this action to a TimelineEventModel.id (the project's timeline
  /// step it contributes to), when the project has a timeline. Empty when
  /// the action isn't tied to a specific step.
  final String stageId;
  final bool visibleToClient;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isAssignedToClient => assignedTo == 'client';
  bool get hasStage => stageId.isNotEmpty;

  ClientActionModel copyWith({
    String? id,
    String? professionalUid,
    String? projectId,
    String? clientId,
    String? title,
    String? description,
    String? assignedTo,
    String? type,
    String? priority,
    String? status,
    String? stageId,
    bool clearStageId = false,
    bool? visibleToClient,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return ClientActionModel(
      id: id ?? this.id,
      professionalUid: professionalUid ?? this.professionalUid,
      projectId: projectId ?? this.projectId,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      stageId: clearStageId ? '' : stageId ?? this.stageId,
      visibleToClient: visibleToClient ?? this.visibleToClient,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'professionalUid': professionalUid,
      'projectId': projectId,
      'clientId': clientId,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'type': type,
      'priority': priority,
      'status': status,
      'stageId': stageId,
      'visibleToClient': visibleToClient,
      'dueDate': dueDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'completedAt': completedAt,
    };
  }

  factory ClientActionModel.fromJson(Map<String, dynamic> json) {
    return ClientActionModel(
      id: json['id'] ?? '',
      professionalUid: json['professionalUid'] ?? json['professionalId'] ?? '',
      projectId: json['projectId'] ?? '',
      clientId: json['clientId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      assignedTo: json['assignedTo'] ?? 'professional',
      type: json['type'] ?? 'information',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      stageId: json['stageId'] ?? '',
      visibleToClient: json['visibleToClient'] ?? true,
      dueDate: _dateFromJson(json['dueDate']),
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
      completedAt: _dateFromJson(json['completedAt']),
    );
  }
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime?;
}

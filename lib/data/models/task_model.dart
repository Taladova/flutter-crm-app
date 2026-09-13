class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.projectName,
    required this.projectId,
    required this.status,
    required this.priority,
    required this.deadline,
    this.visibleToClient = true,
    this.internal = false,
    this.isPrivate = false,
    this.assignedTo = 'professional',
  });

  final String id;
  final String title;
  final String projectName;
  final String projectId;
  final String status;
  final String priority;
  final String deadline;
  final bool visibleToClient;
  final bool internal;
  final bool isPrivate;
  final String assignedTo;

  bool get isVisibleInClientPortal => !internal && !isPrivate;
  bool get isAssignedToClient => assignedTo == 'client';

  TaskModel copyWith({
    String? id,
    String? title,
    String? projectName,
    String? projectId,
    String? status,
    String? priority,
    String? deadline,
    bool? visibleToClient,
    bool? internal,
    bool? isPrivate,
    String? assignedTo,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      projectName: projectName ?? this.projectName,
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      deadline: deadline ?? this.deadline,
      visibleToClient: visibleToClient ?? this.visibleToClient,
      internal: internal ?? this.internal,
      isPrivate: isPrivate ?? this.isPrivate,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'projectName': projectName,
      'projectId': projectId,
      'status': status,
      'priority': priority,
      'deadline': deadline,
      'visibleToClient': visibleToClient,
      'internal': internal,
      'private': isPrivate,
      'assignedTo': assignedTo,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final internal = json['internal'] == true;
    final isPrivate = json['private'] == true;

    return TaskModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      projectName: json['projectName'] ?? '',
      projectId: json['projectId'] ?? '',
      status: json['status'] ?? 'À faire',
      priority: json['priority'] ?? 'Moyenne',
      deadline: json['deadline'] ?? '',
      visibleToClient: json['visibleToClient'] ?? true,
      internal: internal,
      isPrivate: isPrivate,
      assignedTo: json['assignedTo'] ?? 'professional',
    );
  }
}

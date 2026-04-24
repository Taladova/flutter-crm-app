class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.projectName,
    required this.projectId,
    required this.status,
    required this.priority,
    required this.deadline,
  });

  final String id;
  final String title;
  final String projectName;
  final String projectId;
  final String status;
  final String priority;
  final String deadline;

  TaskModel copyWith({
    String? id,
    String? title,
    String? projectName,
    String? projectId,
    String? status,
    String? priority,
    String? deadline,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      projectName: projectName ?? this.projectName,
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      deadline: deadline ?? this.deadline,
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
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      projectName: json['projectName'] ?? '',
      projectId: json['projectId'] ?? '',
      status: json['status'] ?? 'À faire',
      priority: json['priority'] ?? 'Moyenne',
      deadline: json['deadline'] ?? '',
    );
  }
}
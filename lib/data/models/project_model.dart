class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.title,
    required this.clientName,
    required this.type,
    required this.status,
    required this.budget,
    required this.deadline,
    required this.progress,
    this.notes = '',
    this.shareToken = '',
  });

  final String id;
  final String title;
  final String clientName;
  final String type;
  final String status;
  final String budget;
  final String deadline;
  final double progress;
  final String notes;
  final String shareToken;

  bool get isShared => shareToken.isNotEmpty;

  ProjectModel copyWith({String? notes, String? shareToken}) {
    return ProjectModel(
      id: id,
      title: title,
      clientName: clientName,
      type: type,
      status: status,
      budget: budget,
      deadline: deadline,
      progress: progress,
      notes: notes ?? this.notes,
      shareToken: shareToken ?? this.shareToken,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'clientName': clientName,
      'type': type,
      'status': status,
      'budget': budget,
      'deadline': deadline,
      'progress': progress,
      'notes': notes,
      'shareToken': shareToken,
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      clientName: json['clientName'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'Planifié',
      budget: json['budget'] ?? '',
      deadline: json['deadline'] ?? '',
      progress: (json['progress'] ?? 0.0).toDouble(),
      notes: json['notes'] ?? '',
      shareToken: json['shareToken'] ?? '',
    );
  }
}

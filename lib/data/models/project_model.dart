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
    this.clientId = '',
    this.currentStep = '',
    this.nextStep = '',
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
  final String clientId;
  final String currentStep;
  final String nextStep;
  final String notes;
  final String shareToken;

  bool get isShared => shareToken.isNotEmpty;

  ProjectModel copyWith({
    String? notes,
    String? shareToken,
    String? status,
    double? progress,
    String? clientId,
    String? currentStep,
    String? nextStep,
  }) {
    return ProjectModel(
      id: id,
      title: title,
      clientName: clientName,
      type: type,
      status: status ?? this.status,
      budget: budget,
      deadline: deadline,
      progress: progress ?? this.progress,
      clientId: clientId ?? this.clientId,
      currentStep: currentStep ?? this.currentStep,
      nextStep: nextStep ?? this.nextStep,
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
      'clientId': clientId,
      'currentStep': currentStep,
      'nextStep': nextStep,
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
      progress: _progressFromJson(json['progress']),
      clientId: json['clientId'] ?? '',
      currentStep: json['currentStep'] ?? '',
      nextStep: json['nextStep'] ?? '',
      notes: json['notes'] ?? '',
      shareToken: json['shareToken'] ?? '',
    );
  }

  static double _progressFromJson(Object? value) {
    final raw = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text.replaceAll(',', '.')) ?? 0.0,
      _ => 0.0,
    };

    if (raw > 1) return (raw / 100).clamp(0.0, 1.0);
    return raw.clamp(0.0, 1.0);
  }
}

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.recipientUid,
    required this.title,
    required this.body,
    required this.type,
    this.projectId = '',
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String recipientUid;
  final String title;
  final String body;
  final String type;
  final String projectId;
  final bool read;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipientUid': recipientUid,
      'title': title,
      'body': body,
      'type': type,
      'projectId': projectId,
      'read': read,
      'createdAt': createdAt,
    };
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] ?? '',
      recipientUid: json['recipientUid'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'info',
      projectId: json['projectId'] ?? '',
      read: json['read'] ?? false,
      createdAt: _dateFromJson(json['createdAt']),
    );
  }
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime?;
}

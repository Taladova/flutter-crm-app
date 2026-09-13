class ClientDocumentModel {
  const ClientDocumentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.clientId,
    required this.uploadedBy,
    required this.status,
    this.projectId = '',
    this.url = '',
    this.storagePath = '',
    this.comment = '',
    this.clientUid = '',
    this.requestId = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String type;
  final String clientId;
  final String projectId;
  final String uploadedBy;
  final String url;
  final String storagePath;
  final String status;
  final String comment;
  final String clientUid;
  final String requestId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'clientId': clientId,
      'projectId': projectId,
      'uploadedBy': uploadedBy,
      'url': url,
      'storagePath': storagePath,
      'status': status,
      'comment': comment,
      'clientUid': clientUid,
      'requestId': requestId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ClientDocumentModel.fromJson(Map<String, dynamic> json) {
    return ClientDocumentModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      clientId: json['clientId'] ?? '',
      projectId: json['projectId'] ?? '',
      uploadedBy: json['uploadedBy'] ?? '',
      url: json['url'] ?? '',
      storagePath: json['storagePath'] ?? '',
      status: json['status'] ?? 'À fournir',
      comment: json['comment'] ?? '',
      clientUid: json['clientUid'] ?? '',
      requestId: json['requestId'] ?? '',
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

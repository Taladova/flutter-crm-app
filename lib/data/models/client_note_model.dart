class ClientNoteModel {
  const ClientNoteModel({
    required this.id,
    required this.clientId,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String clientId;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClientNoteModel copyWith({
    String? id,
    String? clientId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientNoteModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ClientNoteModel.fromJson(Map<String, dynamic> json) {
    return ClientNoteModel(
      id: json['id'] ?? '',
      clientId: json['clientId'] ?? '',
      content: json['content'] ?? '',
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

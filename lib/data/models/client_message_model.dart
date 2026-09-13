class ClientMessageModel {
  const ClientMessageModel({
    required this.id,
    required this.senderType,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderType; // 'freelancer' or 'client'
  final String text;
  final DateTime? createdAt;

  bool get isFromFreelancer => senderType == 'freelancer';

  factory ClientMessageModel.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];

    return ClientMessageModel(
      id: id,
      senderType: data['senderType'] ?? 'client',
      text: data['text'] ?? '',
      createdAt: timestamp is DateTime
          ? timestamp
          : (timestamp?.toDate() as DateTime?),
    );
  }
}

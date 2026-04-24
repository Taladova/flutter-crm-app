class ClientModel {
  const ClientModel({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.projectsCount,
    required this.status,
  });

  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final int projectsCount;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'email': email,
      'phone': phone,
      'projectsCount': projectsCount,
      'status': status,
    };
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      company: json['company'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      projectsCount: json['projectsCount'] ?? 0,
      status: json['status'] ?? 'Prospect',
    );
  }
}
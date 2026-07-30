class ClientModel {
  const ClientModel({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.projectsCount,
    required this.status,
    this.notes = '',
  });

  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final int projectsCount;
  final String status;
  final String notes;

  ClientModel copyWith({String? notes}) {
    return ClientModel(
      id: id,
      name: name,
      company: company,
      email: email,
      phone: phone,
      projectsCount: projectsCount,
      status: status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'email': email,
      'phone': phone,
      'projectsCount': projectsCount,
      'status': status,
      'notes': notes,
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
      notes: json['notes'] ?? '',
    );
  }
}
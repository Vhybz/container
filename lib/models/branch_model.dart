class Branch {
  final String code;
  final String name;
  final String location;
  final String? adminId;
  final DateTime createdAt;

  Branch({
    required this.code,
    required this.name,
    required this.location,
    this.adminId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      code: json['code'],
      name: json['name'],
      location: json['location'],
      adminId: json['admin_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'location': location,
      'admin_id': adminId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

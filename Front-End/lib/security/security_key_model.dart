class SecurityKeyModel {
  final String name;
  final int level;

  SecurityKeyModel({
    required this.name,
    required this.level,
  });

  factory SecurityKeyModel.fromJson(Map<String, dynamic> json) {
    return SecurityKeyModel(
      name: json['name'] ?? '',
      level: json['level'] ?? 0,
    );
  }
}

class Country {
  final int id;
  final String name;
  final String? code;

  Country({required this.id, required this.name, this.code});

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
    );
  }
}
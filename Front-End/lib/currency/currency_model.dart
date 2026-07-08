class Currency {
  final int id;
  final String name;
  final String? code;

  Currency({
    required this.id,
    required this.name,
    this.code,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
    );
  }

  // --- AUTOMATIC SYMBOL GENERATOR ---
  String get symbol {
    final c = code?.toUpperCase();
    switch (c) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CHF':
        return '₣';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'MAD':
        return 'د.م.';
      case 'RUB':
        return '₽';
      case 'BRL':
        return '₽';
      case 'ZAR':
        return 'R\$';
      case 'TRY':
        return '₺';
      default:
        // Fallback: If it's an unknown code, just show the first letter
        return c != null && c.isNotEmpty ? c[0] : '?';
    }
  }
}

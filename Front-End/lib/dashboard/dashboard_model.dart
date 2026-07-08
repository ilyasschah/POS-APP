class MonthlySale {
  final int month;
  final int year;
  final double total;

  const MonthlySale({
    required this.month,
    required this.year,
    required this.total,
  });

  factory MonthlySale.fromJson(Map<String, dynamic> json) => MonthlySale(
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num).toInt(),
        total: (json['total'] as num).toDouble(),
      );
}

class HourlySale {
  final int hour;
  final double total;

  const HourlySale({required this.hour, required this.total});

  factory HourlySale.fromJson(Map<String, dynamic> json) => HourlySale(
        hour: (json['hour'] as num).toInt(),
        total: (json['total'] as num).toDouble(),
      );
}

class TopProduct {
  final String productName;
  final double quantity;
  final double total;

  const TopProduct({
    required this.productName,
    required this.quantity,
    required this.total,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        productName: json['productName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
      );
}

class TopProductGroup {
  final String groupName;
  final double total;

  const TopProductGroup({required this.groupName, required this.total});

  factory TopProductGroup.fromJson(Map<String, dynamic> json) =>
      TopProductGroup(
        groupName: json['groupName'] as String,
        total: (json['total'] as num).toDouble(),
      );
}

class TopCustomer {
  final String customerName;
  final double total;

  const TopCustomer({required this.customerName, required this.total});

  factory TopCustomer.fromJson(Map<String, dynamic> json) => TopCustomer(
        customerName: json['customerName'] as String,
        total: (json['total'] as num).toDouble(),
      );
}

class DashboardData {
  final double totalSales;
  final List<MonthlySale> monthlySales;
  final List<HourlySale> hourlySales;
  final List<TopProduct> topProducts;
  final List<TopProductGroup> topProductGroups;
  final List<TopCustomer> topCustomers;

  const DashboardData({
    required this.totalSales,
    required this.monthlySales,
    required this.hourlySales,
    required this.topProducts,
    required this.topProductGroups,
    required this.topCustomers,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        totalSales: (json['totalSales'] as num).toDouble(),
        monthlySales: (json['monthlySales'] as List)
            .map((j) => MonthlySale.fromJson(j as Map<String, dynamic>))
            .toList(),
        hourlySales: (json['hourlySales'] as List)
            .map((j) => HourlySale.fromJson(j as Map<String, dynamic>))
            .toList(),
        topProducts: (json['topProducts'] as List)
            .map((j) => TopProduct.fromJson(j as Map<String, dynamic>))
            .toList(),
        topProductGroups: (json['topProductGroups'] as List)
            .map((j) => TopProductGroup.fromJson(j as Map<String, dynamic>))
            .toList(),
        topCustomers: (json['topCustomers'] as List)
            .map((j) => TopCustomer.fromJson(j as Map<String, dynamic>))
            .toList(),
      );

  static const empty = DashboardData(
    totalSales: 0,
    monthlySales: [],
    hourlySales: [],
    topProducts: [],
    topProductGroups: [],
    topCustomers: [],
  );
}

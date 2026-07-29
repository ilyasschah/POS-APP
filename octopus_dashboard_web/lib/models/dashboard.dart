import '../core/formatters.dart';
import '../core/json_utils.dart';

/// `GET /Dashboard/GetDashboardData` response.
class DashboardData {
  const DashboardData({
    required this.totalSales,
    required this.monthlySales,
    required this.hourlySales,
    required this.topProducts,
    required this.topProductGroups,
    required this.topCustomers,
  });

  final double totalSales;
  final List<MonthlySales> monthlySales;
  final List<HourlySales> hourlySales;
  final List<TopProduct> topProducts;

  /// Decoded but intentionally not rendered by any screen, matching the iOS
  /// original.
  final List<TopProductGroup> topProductGroups;
  final List<TopCustomer> topCustomers;

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    totalSales: asDouble(json['totalSales']),
    monthlySales: asList(json['monthlySales'], MonthlySales.fromJson),
    hourlySales: asList(json['hourlySales'], HourlySales.fromJson),
    topProducts: asList(json['topProducts'], TopProduct.fromJson),
    topProductGroups: asList(
      json['topProductGroups'],
      TopProductGroup.fromJson,
    ),
    topCustomers: asList(json['topCustomers'], TopCustomer.fromJson),
  );
}

class MonthlySales {
  const MonthlySales({this.month, this.year, required this.total});

  final int? month;
  final int? year;
  final double total;

  /// Month number 7 renders as "JUL".
  String get label => Fmt.monthLabel(month);

  factory MonthlySales.fromJson(Map<String, dynamic> json) => MonthlySales(
    month: asIntOrNull(json['month']),
    year: asIntOrNull(json['year']),
    total: asDouble(json['total']),
  );
}

class HourlySales {
  const HourlySales({this.hour, required this.total});

  final int? hour;
  final double total;

  String get label => Fmt.hourLabel(hour);

  factory HourlySales.fromJson(Map<String, dynamic> json) => HourlySales(
    hour: asIntOrNull(json['hour']),
    total: asDouble(json['total']),
  );
}

class TopProduct {
  const TopProduct({
    required this.productName,
    required this.quantity,
    required this.total,
  });

  final String productName;
  final double quantity;
  final double total;

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
    productName: asString(json['productName'], 'Unknown'),
    quantity: asDouble(json['quantity']),
    total: asDouble(json['total']),
  );
}

class TopProductGroup {
  const TopProductGroup({required this.groupName, required this.total});

  final String groupName;
  final double total;

  factory TopProductGroup.fromJson(Map<String, dynamic> json) =>
      TopProductGroup(
        groupName: asString(json['groupName'], 'Unknown'),
        total: asDouble(json['total']),
      );
}

class TopCustomer {
  const TopCustomer({required this.customerName, required this.total});

  final String customerName;
  final double total;

  factory TopCustomer.fromJson(Map<String, dynamic> json) => TopCustomer(
    customerName: asString(json['customerName'], 'Unknown'),
    total: asDouble(json['total']),
  );
}

import 'package:dio/dio.dart';
import 'package:octopus_dashboard_web/api/octopus_api.dart';
import 'package:octopus_dashboard_web/models/dashboard.dart';
import 'package:octopus_dashboard_web/models/document.dart';
import 'package:octopus_dashboard_web/models/product.dart';
import 'package:octopus_dashboard_web/models/stock.dart';
import 'package:octopus_dashboard_web/models/user.dart';

/// In-memory stand-in for the backend, used by widget tests.
///
/// Returns deliberately awkward data — long names, many chart points, a
/// product with no stock row — so layout tests exercise the cases most likely
/// to overflow.
class FakeApi implements OctopusApi {
  FakeApi({this.failWith, this.onTokenExpired});

  /// When set, every call throws this instead of returning data.
  final Object? failWith;
  @override
  final void Function()? onTokenExpired;

  Future<T> _respond<T>(T value) async {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    CancelToken? cancelToken,
  }) => _respond(const LoginResult(success: true, token: 'test-token'));

  @override
  Future<DashboardData> fetchDashboard({
    required DateTime startDate,
    required DateTime endDate,
    CancelToken? cancelToken,
  }) => _respond(
    DashboardData(
      totalSales: 1234567.89,
      monthlySales: [
        for (var month = 1; month <= 12; month++)
          MonthlySales(month: month, year: 2026, total: month * 1000),
      ],
      hourlySales: [
        for (var hour = 8; hour <= 23; hour++)
          HourlySales(hour: hour, total: (hour - 7) * 120),
      ],
      topProducts: const [
        TopProduct(
          productName: 'Extra Large Double Cheeseburger With Everything On It',
          quantity: 40,
          total: 400,
        ),
        TopProduct(productName: 'Pepsi', quantity: 25, total: 250),
      ],
      topProductGroups: const [
        TopProductGroup(groupName: 'Drinks', total: 900),
      ],
      topCustomers: const [
        TopCustomer(
          customerName: 'A Very Long Corporate Customer Name SARL',
          total: 12000,
        ),
        TopCustomer(customerName: 'Walk-in Customer', total: 1200),
      ],
    ),
  );

  static final _products = [
    const Product(
      id: 7,
      name: 'Pepsi',
      code: '0001',
      price: 10,
      cost: 5,
      isTaxInclusivePrice: true,
      isPriceChangeAllowed: false,
      isService: false,
      isUsingDefaultQuantity: true,
      isEnabled: true,
      color: 'Transparent',
      measurementUnit: 'pcs',
    ),
    const Product(
      id: 8,
      name: 'Shwarma Sandwich With Extra Garlic Sauce And Fries',
      code: '0002',
      price: 35,
      cost: 12.5,
      isTaxInclusivePrice: true,
      isPriceChangeAllowed: true,
      isService: false,
      isUsingDefaultQuantity: true,
      isEnabled: true,
      color: 'Transparent',
    ),
  ];

  @override
  Future<List<Product>> fetchProducts({CancelToken? cancelToken}) =>
      _respond(_products);

  @override
  Future<void> updateProductPricing({
    required Product product,
    required double price,
    required double cost,
    CancelToken? cancelToken,
  }) => _respond(null);

  @override
  Future<List<StockEntry>> fetchStocks({CancelToken? cancelToken}) => _respond([
    // Product 7 is split across two warehouses; product 8 has no stock row at
    // all and must still appear, as "Unassigned".
    StockEntry.fromJson(const {
      'id': 1,
      'quantity': 400.0,
      'warehouseId': 17,
      'warehouseName': 'Main Warehouse',
      'productId': 7,
      'productName': 'Pepsi',
    }),
    StockEntry.fromJson(const {
      'id': 2,
      'quantity': 77.0,
      'warehouseId': 18,
      'warehouseName': 'Back Storage Room',
      'productId': 7,
      'productName': 'Pepsi',
    }),
  ]);

  @override
  Future<List<SalesDocument>> fetchDocuments({CancelToken? cancelToken}) =>
      _respond([
        SalesDocument(
          id: 55,
          number: 'POS1-200-000001',
          customerName: 'Walk-in Customer',
          documentTypeName: 'Sales',
          total: 35,
          date: DateTime(2026, 7, 16),
        ),
      ]);

  @override
  Future<List<DocumentLineItem>> fetchDocumentItems({
    required int documentId,
    CancelToken? cancelToken,
  }) => _respond(const [
    DocumentLineItem(
      id: 56,
      productName: 'Shwarma',
      quantity: 1,
      price: 35,
      total: 35,
    ),
  ]);

  @override
  Future<List<StaffUser>> fetchUsers({CancelToken? cancelToken}) =>
      _respond(const [
        StaffUser(
          id: 9,
          accessLevel: 0,
          isEnabled: true,
          username: 'ilyasschah',
          email: 'ilyasschah18@gmail.com',
        ),
        StaffUser(
          id: 10,
          accessLevel: 1,
          isEnabled: false,
          firstName: 'Disabled',
          lastName: 'Cashier',
        ),
      ]);

  @override
  Future<void> adminResetPassword({
    required int userId,
    required String newPassword,
    CancelToken? cancelToken,
  }) => _respond(null);

  @override
  void close() {}
}

/// Counts fetches, to verify that every visit to a screen re-loads its data.
class CountingApi extends FakeApi {
  int productCalls = 0;

  @override
  Future<List<Product>> fetchProducts({CancelToken? cancelToken}) {
    productCalls++;
    return super.fetchProducts(cancelToken: cancelToken);
  }
}

import 'package:dio/dio.dart';
import 'package:octopus_dashboard_web/api/octopus_api.dart';
import 'package:octopus_dashboard_web/models/dashboard.dart';
import 'package:octopus_dashboard_web/models/document.dart';
import 'package:octopus_dashboard_web/models/document_lookups.dart';
import 'package:octopus_dashboard_web/models/pos_session.dart';
import 'package:octopus_dashboard_web/models/product.dart';
import 'package:octopus_dashboard_web/models/stock.dart';
import 'package:octopus_dashboard_web/models/stock_rule.dart';
import 'package:octopus_dashboard_web/models/user.dart';

/// In-memory stand-in for the backend, used by widget tests.
///
/// Returns deliberately awkward data — long names, many chart points, a
/// product with no stock row — so layout tests exercise the cases most likely
/// to overflow.
class FakeApi implements OctopusApi {
  FakeApi({this.failWith, this.onTokenExpired, this.companyId = 7});

  /// When set, every call throws this instead of returning data.
  final Object? failWith;

  /// The tenant a real client would scope its requests to.
  @override
  final int? companyId;

  @override
  final void Function()? onTokenExpired;

  // Every write, recorded in order, so tests can assert what was sent.
  final List<Map<String, dynamic>> createdDocuments = [];
  final List<Map<String, dynamic>> updatedDocuments = [];
  final List<int> deletedDocuments = [];
  final List<Map<String, dynamic>> addedItems = [];
  final List<Map<String, dynamic>> updatedItems = [];
  final List<int> deletedItems = [];
  final List<(int, int)> addedItemTaxes = [];
  final List<(int, int)> deletedItemTaxes = [];
  final List<int> numbersIssuedFor = [];
  int _nextId = 900;

  Future<T> _respond<T>(T value) async {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    CancelToken? cancelToken,
  }) => _respond(
        // A real login answers with the user's company; without one the
        // controller refuses to sign in, which is the point of the change.
        const LoginResult(success: true, token: 'test-token', companyId: 7),
      );

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

  /// Product 7 (477 in stock) sits under both thresholds, so the row carries
  /// every tag and the LOW flag — with a supplier name long enough to wrap.
  @override
  Future<List<StockRule>> fetchStockRules({CancelToken? cancelToken}) =>
      _respond(const [
        StockRule(
          productId: 7,
          supplierName: 'A Very Long Beverage Distribution Company SARL',
          reorderPoint: 600,
          preferredQuantity: 1000,
          isLowStockWarningEnabled: true,
          lowStockWarningQuantity: 500,
        ),
      ]);

  @override
  Future<List<SalesDocument>> fetchDocuments({CancelToken? cancelToken}) =>
      _respond([
        // Rung up on a register: shown, never edited from the dashboard.
        SalesDocument(
          id: 55,
          number: 'POS1-200-000001',
          customerName: 'Walk-in Customer',
          documentTypeName: 'Sales',
          total: 35,
          date: DateTime(2026, 7, 16),
          documentTypeId: 2,
          customerId: 1,
          userId: 9,
          warehouseId: 17,
          orderNumber: '#12',
        ),
        // Created by hand: editable and deletable.
        SalesDocument(
          id: 56,
          number: '26-100-000004',
          customerName: 'Atlas Beverage Distribution Company SARL',
          documentTypeName: 'Purchase',
          total: 240,
          date: DateTime(2026, 9, 14),
          documentTypeId: 1,
          customerId: 2,
          userId: 9,
          warehouseId: 17,
          warehouseName: 'Main Warehouse',
        ),
      ]);

  @override
  Future<List<DocumentLineItem>> fetchDocumentItems({
    required int documentId,
    CancelToken? cancelToken,
  }) => _respond(
    documentId == 56
        ? const [
            DocumentLineItem(
              id: 57,
              productId: 7,
              productName: 'Pepsi',
              quantity: 24,
              price: 10,
              priceBeforeTax: 10,
              total: 240,
            ),
          ]
        : const [
            DocumentLineItem(
              id: 56,
              productId: 8,
              productName: 'Shwarma',
              quantity: 1,
              price: 35,
              total: 35,
            ),
          ],
  );

  static const _types = [
    DocumentTypeOption(id: 1, name: 'Purchase', code: '100', categoryId: 1, categoryName: 'Expenses', stockDirection: 1),
    DocumentTypeOption(id: 2, name: 'Sales', code: '200', categoryId: 2, categoryName: 'Sales', stockDirection: 2),
    DocumentTypeOption(id: 3, name: 'Inventory Count', code: '300', categoryId: 3, categoryName: 'Inventory', stockDirection: 1),
    DocumentTypeOption(id: 4, name: 'Refund', code: '220', categoryId: 2, categoryName: 'Sales', stockDirection: 1),
    DocumentTypeOption(id: 5, name: 'Stock Return', code: '120', categoryId: 1, categoryName: 'Expenses', stockDirection: 2),
    DocumentTypeOption(id: 6, name: 'Loss And Damage', code: '400', categoryId: 4, categoryName: 'Loss', stockDirection: 2),
    DocumentTypeOption(id: 7, name: 'Proforma', code: '230', categoryId: 2, categoryName: 'Sales', stockDirection: 0),
  ];

  @override
  Future<List<DocumentTypeOption>> fetchDocumentTypes({
    CancelToken? cancelToken,
  }) => _respond(_types);

  @override
  Future<List<CustomerOption>> fetchCustomers({CancelToken? cancelToken}) =>
      _respond(const [
        CustomerOption(id: 1, name: 'Walk-in Customer'),
        CustomerOption(
          id: 2,
          name: 'Atlas Beverage Distribution Company SARL',
          isCustomer: false,
          isSupplier: true,
        ),
      ]);

  @override
  Future<List<WarehouseOption>> fetchWarehouses({CancelToken? cancelToken}) =>
      _respond(const [
        WarehouseOption(id: 17, name: 'Main Warehouse'),
        WarehouseOption(id: 18, name: 'Back Storage Room'),
      ]);

  @override
  Future<List<TaxOption>> fetchTaxes({CancelToken? cancelToken}) =>
      _respond(const [
        TaxOption(id: 1, name: 'VAT', rate: 20),
        TaxOption(id: 2, name: 'Eco levy', rate: 2, isFixed: true),
      ]);

  @override
  Future<String> fetchNextDocumentNumber({
    required int documentTypeId,
    CancelToken? cancelToken,
  }) {
    numbersIssuedFor.add(documentTypeId);
    final code = _types.firstWhere((t) => t.id == documentTypeId).code;
    return _respond('26-$code-${numbersIssuedFor.length.toString().padLeft(6, '0')}');
  }

  /// One-shot failures by call name — `addDocumentItem` for the next call, or
  /// `addDocumentItem:2` for the second one — to exercise a save that stops
  /// half way.
  final Map<String, Object> failOnce = {};
  final Map<String, int> _calls = {};

  void _failIfAsked(String call) {
    final n = _calls[call] = (_calls[call] ?? 0) + 1;
    final error = failOnce.remove('$call:$n') ?? failOnce.remove(call);
    if (error != null) throw error;
  }

  @override
  Future<int> createDocument(Map<String, dynamic> body) async {
    _failIfAsked('createDocument');
    createdDocuments.add(body);
    return _respond(_nextId++);
  }

  @override
  Future<void> updateDocument(Map<String, dynamic> body) {
    updatedDocuments.add(body);
    return _respond(null);
  }

  @override
  Future<void> deleteDocument({required int id}) {
    deletedDocuments.add(id);
    return _respond(null);
  }

  @override
  Future<int> addDocumentItem(Map<String, dynamic> body) async {
    _failIfAsked('addDocumentItem');
    addedItems.add(body);
    return _respond(_nextId++);
  }

  @override
  Future<void> updateDocumentItem(Map<String, dynamic> body) {
    updatedItems.add(body);
    return _respond(null);
  }

  @override
  Future<void> deleteDocumentItem({required int id}) {
    deletedItems.add(id);
    return _respond(null);
  }

  @override
  Future<List<int>> fetchDocumentItemTaxIds({
    required int documentItemId,
    CancelToken? cancelToken,
  }) => _respond(const []);

  @override
  Future<void> addDocumentItemTax({
    required int documentItemId,
    required int taxId,
  }) {
    addedItemTaxes.add((documentItemId, taxId));
    return _respond(null);
  }

  @override
  Future<void> deleteDocumentItemTax({
    required int documentItemId,
    required int taxId,
  }) {
    deletedItemTaxes.add((documentItemId, taxId));
    return _respond(null);
  }

  /// One session per lifecycle state, plus the two flags that must never be
  /// invisible: a force-close and a late arrival. Register names are long on
  /// purpose — the row has to ellipsize rather than overflow.
  static final _sessions = [
    PosSession(
      id: 142,
      companyId: 25,
      posDeviceId: 3,
      posDeviceName: 'POS1',
      localId: 'a4f1c0de-0000-4000-8000-000000000142',
      openedByUserId: 9,
      openedAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 12)),
      openingCash: 200,
      status: 11,
      statusName: 'OPENED',
      forceClosed: false,
      hasLateArrivals: false,
      lastModified: DateTime.now(),
    ),
    PosSession(
      id: 141,
      companyId: 25,
      posDeviceId: 3,
      posDeviceName: 'POS1',
      openedByUserId: 10,
      openedAt: DateTime(2026, 7, 15, 9),
      closedByUserId: 9,
      closedAt: DateTime(2026, 7, 15, 18, 12),
      openingCash: 200,
      expectedCash: 4137.70,
      actualEndingCash: 4097.70,
      cashDifference: -40,
      closingNote: 'Two 20 DH notes missing after the evening rush; '
          'authorised by the manager on shift.',
      status: 13,
      statusName: 'CLOSED',
      forceClosed: false,
      hasLateArrivals: true,
      lastModified: DateTime(2026, 7, 15, 18, 12),
    ),
    PosSession(
      id: 140,
      companyId: 25,
      posDeviceId: 4,
      posDeviceName: 'Terrace Register With A Very Long Display Name',
      openedByUserId: 10,
      openedAt: DateTime(2026, 7, 14, 11, 30),
      closedByUserId: 9,
      closedAt: DateTime(2026, 7, 14, 23, 59),
      openingCash: 150,
      status: 13,
      statusName: 'CLOSED',
      forceClosed: true,
      forceClosedByUserId: 9,
      forceCloseReason:
          'Tablet fell off the terrace counter and would not boot; drawer '
          'counted by hand the next morning.',
      hasLateArrivals: false,
      lastModified: DateTime(2026, 7, 14, 23, 59),
    ),
    PosSession(
      id: 139,
      companyId: 25,
      posDeviceId: 5,
      posDeviceName: 'POS2',
      openedByUserId: 9,
      openedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      openingCash: 0,
      status: 10,
      statusName: 'OPENING_CONTROL',
      forceClosed: false,
      hasLateArrivals: false,
      lastModified: DateTime.now(),
    ),
  ];

  @override
  Future<List<PosSession>> fetchPosSessions({
    int take = 50,
    CancelToken? cancelToken,
  }) => _respond(_sessions.take(take).toList());

  @override
  Future<PosSessionSummary> fetchPosSessionSummary({
    required int sessionId,
    CancelToken? cancelToken,
  }) => _respond(
    PosSessionSummary(
      sessionId: sessionId,
      status: 13,
      statusName: 'CLOSED',
      openedAt: DateTime(2026, 7, 15, 9),
      openedByUserId: 9,
      orderCount: 37,
      openingCash: 200,
      cashPayments: 3937.70,
      cashIn: 100,
      cashOut: 100,
      expectedCash: 4137.70,
      totalTaken: 6218.40,
      maxCashDifference: 20,
      // Deliberately not configured, so the "cash methods were inferred"
      // warning is exercised by the widget tests.
      cashMethodsConfigured: false,
      methods: const [
        PosSessionMethod(
          paymentTypeId: 1,
          paymentTypeName: 'Cash',
          isCash: true,
          expected: 3937.70,
        ),
        PosSessionMethod(
          paymentTypeId: 2,
          paymentTypeName: 'Bank Card (Contactless Terminal)',
          isCash: false,
          expected: 2100.70,
        ),
        PosSessionMethod(
          paymentTypeId: 3,
          paymentTypeName: 'Meal Voucher',
          isCash: false,
          expected: 180,
        ),
      ],
    ),
  );

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

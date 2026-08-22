import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_dashboard_web/core/formatters.dart';
import 'package:octopus_dashboard_web/features/dashboard/date_presets.dart';
import 'package:octopus_dashboard_web/models/pos_session.dart';
import 'package:octopus_dashboard_web/models/product.dart';
import 'package:octopus_dashboard_web/models/stock.dart';
import 'package:octopus_dashboard_web/models/user.dart';

/// A realistic `/Products/GetAll` row, including the huge base64 `image` field
/// the client is expected to ignore.
Map<String, dynamic> productJson({
  int id = 7,
  String name = 'Pepsi',
  String? code = '0001',
  double price = 10,
  double cost = 5,
}) => {
  'id': id,
  'companyId': 25,
  'productGroupId': 6,
  'productGroupName': 'Drinks',
  'name': name,
  'code': code,
  'plu': 1,
  'measurementUnit': 'pcs',
  'price': price,
  'isTaxInclusivePrice': true,
  'currencyId': null,
  'isPriceChangeAllowed': false,
  'isService': false,
  'isUsingDefaultQuantity': true,
  'isEnabled': true,
  'description': 'pepsi',
  'dateCreated': '2026-07-05T20:01:24.884Z',
  'dateUpdated': '2026-07-28T20:06:22.651Z',
  'cost': cost,
  'markup': 0.0,
  'color': 'Transparent',
  'ageRestriction': null,
  'lastPurchasePrice': null,
  'rank': null,
  'barcodes': ['1783281694498'],
  'image': 'iVBORw0KGgoAAAANSUhEUg' * 500,
  'lastModified': '2026-07-28T20:06:22.657Z',
};

void main() {
  group('Product update payload', () {
    test('resends every required field, not just the edited ones', () {
      final product = Product.fromJson(productJson());
      final body = product.toUpdateJson(newPrice: 12.5, newCost: 6);

      // The server rejects partial updates: all of these are non-nullable.
      for (final key in const [
        'name',
        'price',
        'isTaxInclusivePrice',
        'isPriceChangeAllowed',
        'isService',
        'isUsingDefaultQuantity',
        'isEnabled',
        'cost',
        'color',
      ]) {
        expect(body.containsKey(key), isTrue, reason: '$key must be present');
        expect(body[key], isNotNull, reason: '$key must be non-null');
      }

      expect(body['id'], 7);
      expect(body['price'], 12.5);
      expect(body['cost'], 6);
      // Untouched fields round-trip unchanged.
      expect(body['name'], 'Pepsi');
      expect(body['isTaxInclusivePrice'], true);
      expect(body['isPriceChangeAllowed'], false);
      expect(body['color'], 'Transparent');
      expect(body['measurementUnit'], 'pcs');
      expect(body['productGroupId'], 6);
    });

    test('never decodes or re-sends the base64 image blob', () {
      final product = Product.fromJson(productJson());
      final body = product.toUpdateJson(newPrice: 1, newCost: 1);
      expect(body.containsKey('image'), isFalse);
    });

    test('falls back to the API default when color is missing', () {
      final json = productJson()..remove('color');
      expect(Product.fromJson(json).color, 'Transparent');
    });

    test('search matches name or code, case-insensitively', () {
      final product = Product.fromJson(productJson());
      expect(product.matches('pep'), isTrue);
      expect(product.matches('PEP'), isTrue);
      expect(product.matches('0001'), isTrue);
      expect(product.matches(''), isTrue);
      expect(product.matches('shwarma'), isFalse);
    });
  });

  group('Stock left-join', () {
    StockEntry entry({
      required int productId,
      required int warehouseId,
      required String warehouseName,
      required double quantity,
    }) => StockEntry.fromJson({
      'id': warehouseId * 100 + productId,
      'quantity': quantity,
      'warehouseId': warehouseId,
      'warehouseName': warehouseName,
      'productId': productId,
      'productName': 'x',
      'companyId': 25,
      'companyName': 'FUTUR3',
    });

    test('lists every product, including ones with no stock record', () {
      final products = [
        Product.fromJson(productJson(id: 7, name: 'Pepsi')),
        Product.fromJson(productJson(id: 8, name: 'Shwarma')),
      ];
      // Only product 7 has stock anywhere.
      final stocks = [
        entry(
          productId: 7,
          warehouseId: 17,
          warehouseName: 'Main',
          quantity: 477,
        ),
      ];

      final joined = ProductStock.join(products, stocks);

      expect(joined, hasLength(2));
      final shwarma = joined.firstWhere((r) => r.product.id == 8);
      expect(shwarma.isUnassigned, isTrue);
      expect(shwarma.totalQuantity, 0);
    });

    test('sums quantities across warehouses', () {
      final products = [Product.fromJson(productJson(id: 7))];
      final stocks = [
        entry(
          productId: 7,
          warehouseId: 17,
          warehouseName: 'Main',
          quantity: 400,
        ),
        entry(
          productId: 7,
          warehouseId: 18,
          warehouseName: 'Back',
          quantity: 77,
        ),
      ];

      final row = ProductStock.join(products, stocks).single;
      expect(row.totalQuantity, 477);
      expect(row.isMultiWarehouse, isTrue);
      expect(row.isUnassigned, isFalse);
    });

    test('sorts alphabetically by product name', () {
      final products = [
        Product.fromJson(productJson(id: 1, name: 'Zaatar')),
        Product.fromJson(productJson(id: 2, name: 'apple')),
        Product.fromJson(productJson(id: 3, name: 'Mango')),
      ];

      final names = ProductStock.join(
        products,
        const [],
      ).map((r) => r.product.name).toList();

      expect(names, ['apple', 'Mango', 'Zaatar']);
    });

    test('ignores stock rows for products not in the product list', () {
      final products = [Product.fromJson(productJson(id: 7))];
      final stocks = [
        entry(
          productId: 999,
          warehouseId: 17,
          warehouseName: 'Main',
          quantity: 5,
        ),
      ];
      expect(ProductStock.join(products, stocks), hasLength(1));
    });
  });

  group('StaffUser', () {
    StaffUser user(Map<String, dynamic> overrides) => StaffUser.fromJson({
      'id': 9,
      'companyId': 25,
      'firstName': 'ilyass',
      'lastName': 'chah',
      'username': 'ilyasschah',
      'accessLevel': 0,
      'isEnabled': true,
      'email': 'ilyasschah18@gmail.com',
      ...overrides,
    });

    test('display name prefers username, then full name, then email', () {
      expect(user(const {}).displayName, 'ilyasschah');
      expect(user(const {'username': null}).displayName, 'ilyass chah');
      expect(
        user(const {'username': null, 'firstName': null, 'lastName': null})
            .displayName,
        'ilyasschah18@gmail.com',
      );
      expect(
        user(const {
          'username': null,
          'firstName': null,
          'lastName': null,
          'email': null,
        }).displayName,
        'Unknown',
      );
    });

    test('role is derived from accessLevel', () {
      expect(user(const {'accessLevel': 0}).roleName, 'Admin');
      expect(user(const {'accessLevel': 1}).roleName, 'Cashier');
      expect(user(const {'accessLevel': 7}).roleName, 'Cashier');
    });

    test('status reads isEnabled directly, not inverted', () {
      expect(user(const {'isEnabled': true}).isEnabled, isTrue);
      expect(user(const {'isEnabled': false}).isEnabled, isFalse);
    });
  });

  group('POS sessions', () {
    /// A realistic `/PosSession/History` row. The timestamps are spelled the
    /// way the API actually sends them: no zone suffix, and up to seven
    /// fractional digits.
    PosSession session([Map<String, dynamic> overrides = const {}]) =>
        PosSession.fromJson({
          'id': 141,
          'localId': 'a4f1c0de-0000-4000-8000-000000000141',
          'companyId': 25,
          'posDeviceId': 3,
          'posDeviceName': 'POS1',
          'openedByUserId': 10,
          'openedAt': '2026-07-15T09:00:00',
          'closedByUserId': 9,
          'closedAt': '2026-07-15T18:12:00.1234567',
          'openingCash': 200.0,
          'expectedCash': 4137.70,
          'actualEndingCash': 4097.70,
          'cashDifference': -40.0,
          'closingNote': null,
          'status': 13,
          'statusName': 'CLOSED',
          'forceClosed': false,
          'forceClosedByUserId': null,
          'forceCloseReason': null,
          'hasLateArrivals': false,
          'lastModified': '2026-07-15T18:12:00Z',
          ...overrides,
        });

    test('status maps to the 10-13 lifecycle', () {
      expect(session(const {'status': 10}).state,
          PosSessionState.openingControl);
      expect(session(const {'status': 11}).state, PosSessionState.opened);
      expect(session(const {'status': 12}).state,
          PosSessionState.closingControl);
      expect(session(const {'status': 13}).state, PosSessionState.closed);
    });

    test('attendance shift codes never read as a session state', () {
      // 0 and 1 belong to attendance shifts, which share the Shift table.
      // Reading 1 as "trading" is exactly the confusion the disjoint ranges
      // exist to prevent.
      expect(session(const {'status': 0}).state, PosSessionState.unknown);
      expect(session(const {'status': 1}).state, PosSessionState.unknown);
      expect(session(const {'status': 1}).isLive, isFalse);
    });

    test('opening and closing control both still hold the register', () {
      expect(session(const {'status': 10}).isLive, isTrue);
      expect(session(const {'status': 11}).isLive, isTrue);
      expect(session(const {'status': 12}).isLive, isTrue);
      expect(session(const {'status': 13}).isLive, isFalse);
    });

    test('unzoned timestamps are read as UTC, not local wall-clock', () {
      // The server writes DateTime.UtcNow; EF hands it back as
      // Kind=Unspecified, so it arrives with no Z. Taking it at face value
      // would shift every session time by the viewer's offset.
      expect(session().openedAt, DateTime.utc(2026, 7, 15, 9).toLocal());
    });

    test('seven-digit fractional seconds still parse', () {
      expect(
        session().closedAt,
        DateTime.utc(2026, 7, 15, 18, 12, 0, 123, 456).toLocal(),
      );
    });

    test('needs attention on variance, force-close or late arrivals', () {
      expect(session().needsAttention, isTrue); // -40.00 short
      expect(
        session(const {'cashDifference': 0.0, 'forceClosed': true})
            .needsAttention,
        isTrue,
      );
      expect(
        session(const {'cashDifference': 0.0, 'hasLateArrivals': true})
            .needsAttention,
        isTrue,
      );
      expect(
        session(const {'cashDifference': 0.0}).needsAttention,
        isFalse,
      );
    });

    test('rounding noise is not a cash difference', () {
      expect(session(const {'cashDifference': 0.004}).hasCashDifference,
          isFalse);
      expect(session(const {'cashDifference': -0.02}).hasCashDifference,
          isTrue);
    });

    test('register name falls back to the device id, then to unknown', () {
      expect(session().registerName, 'POS1');
      expect(
        session(const {'posDeviceName': null}).registerName,
        'Register #3',
      );
      expect(
        session(const {'posDeviceName': null, 'posDeviceId': null})
            .registerName,
        'Unknown register',
      );
    });

    test('a live session is measured against now, not a null close', () {
      final live = session({
        'status': 11,
        'closedAt': null,
        'openedAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
      });
      expect(live.elapsed!.inMinutes, closeTo(120, 1));
    });

    test('average sale guards against a session with no orders', () {
      PosSessionSummary summary(int orders) => PosSessionSummary.fromJson({
        'sessionId': 141,
        'status': 13,
        'orderCount': orders,
        'openingCash': 200.0,
        'cashPayments': 3937.70,
        'cashIn': 0.0,
        'cashOut': 0.0,
        'expectedCash': 4137.70,
        'totalTaken': 6218.40,
        'methods': const [],
        'maxCashDifference': 20.0,
        'cashMethodsConfigured': false,
      });

      expect(summary(0).averageSale, 0);
      expect(summary(37).averageSale, closeTo(168.06, 0.01));
    });
  });

  group('Date presets', () {
    // A Thursday.
    final reference = DateTime(2026, 7, 16, 14, 30);

    test('yesterday covers the whole previous day', () {
      final range = DatePreset.yesterday.resolve(reference);
      expect(range.start, DateTime(2026, 7, 15));
      expect(range.end, DateTime(2026, 7, 15, 23, 59, 59));
    });

    test('this week starts on Monday and runs to now', () {
      final range = DatePreset.thisWeek.resolve(reference);
      expect(range.start, DateTime(2026, 7, 13));
      expect(range.start.weekday, DateTime.monday);
      expect(range.end, reference);
    });

    test('last week covers the full preceding Monday-Sunday', () {
      final range = DatePreset.lastWeek.resolve(reference);
      expect(range.start, DateTime(2026, 7, 6));
      expect(range.end, DateTime(2026, 7, 12, 23, 59, 59));
    });

    test('last month covers the full previous month', () {
      final range = DatePreset.lastMonth.resolve(reference);
      expect(range.start, DateTime(2026, 6));
      expect(range.end, DateTime(2026, 6, 30, 23, 59, 59));
    });

    test('last month rolls back across a year boundary', () {
      final range = DatePreset.lastMonth.resolve(DateTime(2026, 1, 15));
      expect(range.start, DateTime(2025, 12));
      expect(range.end, DateTime(2025, 12, 31, 23, 59, 59));
    });

    test('last year covers the full previous year', () {
      final range = DatePreset.lastYear.resolve(reference);
      expect(range.start, DateTime(2025));
      expect(range.end, DateTime(2025, 12, 31, 23, 59, 59));
    });
  });

  group('Formatting', () {
    test('currency is en_US formatted with a DH suffix', () {
      expect(Fmt.currency(1234.5), '1,234.50 DH');
      expect(Fmt.currency(0), '0.00 DH');
      expect(Fmt.currency(null), '0.00 DH');
    });

    test('api date uses local calendar fields and never shifts a day', () {
      // Late-evening local times are where a UTC round-trip would roll over
      // to the next day for anyone east of UTC.
      expect(Fmt.apiDate(DateTime(2026, 7, 16, 23, 30)), '2026-07-16');
      expect(Fmt.apiDate(DateTime(2026, 1, 1)), '2026-01-01');
    });

    test('quantity trims trailing zeros', () {
      expect(Fmt.quantity(40), '40');
      expect(Fmt.quantity(2.5), '2.5');
    });

    test('parses both zoned and unzoned backend timestamps', () {
      // Unzoned values are local wall-clock and must not be shifted.
      final unzoned = Fmt.parseDate('2026-07-16T00:00:00')!;
      expect(unzoned.year, 2026);
      expect(unzoned.month, 7);
      expect(unzoned.day, 16);
      expect(unzoned.isUtc, isFalse);

      // Zoned values come back converted to local time.
      expect(Fmt.parseDate('2026-07-16T10:10:37.307Z')!.isUtc, isFalse);
      expect(Fmt.parseDate(null), isNull);
      expect(Fmt.parseDate(''), isNull);
    });

    test('month labels are three-letter uppercase', () {
      expect(Fmt.monthLabel(7), 'JUL');
      expect(Fmt.monthLabel(1), 'JAN');
    });
  });
}

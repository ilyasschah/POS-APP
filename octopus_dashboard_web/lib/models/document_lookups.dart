import '../core/formatters.dart';
import '../core/json_utils.dart';
import 'product.dart';
import 'stock.dart';
import 'user.dart';

/// `DocumentCategory` ids, as seeded server-side (GlobalDefaultsSeeder.cs).
abstract final class DocumentCategoryIds {
  static const int expenses = 1;
  static const int sales = 2;
  static const int inventory = 3;
  static const int loss = 4;
}

/// The one type id whose lines mean something different: an inventory count
/// moves stock by its VARIANCE (counted − expected), never by its quantity.
abstract final class DocumentTypeIds {
  static const int inventoryCount = 3;
}

/// A row from `GET /DocumentType/GetAll` — global, not company-scoped.
class DocumentTypeOption {
  const DocumentTypeOption({
    required this.id,
    required this.name,
    required this.code,
    required this.categoryId,
    required this.categoryName,
    required this.stockDirection,
  });

  final int id;
  final String name;

  /// The series code a document number is built from — `26-220-000001`.
  final String code;
  final int categoryId;
  final String categoryName;

  /// 1 brings goods into the warehouse, 2 takes them out, 0 moves nothing.
  final int stockDirection;

  static const int stockIn = 1;
  static const int stockOut = 2;

  bool get isInventoryCount => id == DocumentTypeIds.inventoryCount;

  /// Suppliers for Expenses (a purchase), customers for everything else.
  bool get tradesWithSuppliers => categoryId == DocumentCategoryIds.expenses;

  /// A sale is priced at the selling price; everything else at cost.
  bool get pricesAtCost => categoryId != DocumentCategoryIds.sales;

  String get label => code.isEmpty ? name : '$code  $name';

  factory DocumentTypeOption.fromJson(Map<String, dynamic> json) =>
      DocumentTypeOption(
        id: asInt(json['id']),
        name: asString(json['name'], '—'),
        code: asString(json['code']),
        categoryId: asInt(json['documentCategoryId']),
        categoryName: asString(json['documentCategoryName']),
        stockDirection: asInt(json['stockDirection']),
      );
}

/// A row from `GET /DocumentCategory/GetAll`.
class DocumentCategoryOption {
  const DocumentCategoryOption({required this.id, required this.name});

  final int id;
  final String name;

  factory DocumentCategoryOption.fromJson(Map<String, dynamic> json) =>
      DocumentCategoryOption(
        id: asInt(json['id']),
        name: asString(json['name'], '—'),
      );
}

/// A row from `GET /Customer/GetAllCustomers` — customers AND suppliers.
class CustomerOption {
  const CustomerOption({
    required this.id,
    required this.name,
    this.code,
    this.isEnabled = true,
    this.isCustomer = true,
    this.isSupplier = false,
  });

  final int id;
  final String name;
  final String? code;
  final bool isEnabled;
  final bool isCustomer;
  final bool isSupplier;

  String get displayName => name.trim().isEmpty ? (code ?? '#$id') : name;

  factory CustomerOption.fromJson(Map<String, dynamic> json) => CustomerOption(
    id: asInt(json['id']),
    name: asString(json['name']),
    code: asStringOrNull(json['code']),
    isEnabled: asBool(json['isEnabled'], true),
    isCustomer: asBool(json['isCustomer'], true),
    isSupplier: asBool(json['isSupplier']),
  );
}

/// A row from `GET /Warehouses/GetAll`.
class WarehouseOption {
  const WarehouseOption({required this.id, required this.name});

  final int id;
  final String name;

  factory WarehouseOption.fromJson(Map<String, dynamic> json) =>
      WarehouseOption(
        id: asInt(json['id']),
        name: asString(json['name'], 'Warehouse'),
      );
}

/// A row from `GET /Taxes/GetAllTaxes`.
class TaxOption {
  const TaxOption({
    required this.id,
    required this.name,
    required this.rate,
    this.isFixed = false,
    this.isEnabled = true,
  });

  final int id;
  final String name;

  /// A percentage — or, when [isFixed], a flat amount per unit.
  final double rate;
  final bool isFixed;
  final bool isEnabled;

  /// `VAT 20%`, or `Eco levy 2.00 DH per unit` for a fixed tax.
  String get label => isFixed
      ? '$name ${Fmt.currency(rate)} per unit'
      : '$name ${Fmt.quantity(rate)}%';

  factory TaxOption.fromJson(Map<String, dynamic> json) => TaxOption(
    id: asInt(json['id']),
    name: asString(json['name'], 'Tax'),
    rate: asDouble(json['rate']),
    isFixed: asBool(json['isFixed']),
    isEnabled: asBool(json['isEnabled'], true),
  );
}

/// Everything the document editor picks from, loaded once when it opens.
class DocumentLookups {
  const DocumentLookups({
    required this.types,
    required this.customers,
    required this.warehouses,
    required this.taxes,
    required this.users,
    required this.products,
    required this.stocks,
  });

  final List<DocumentTypeOption> types;
  final List<CustomerOption> customers;
  final List<WarehouseOption> warehouses;
  final List<TaxOption> taxes;
  final List<StaffUser> users;
  final List<Product> products;
  final List<StockEntry> stocks;

  DocumentTypeOption? typeById(int? id) =>
      types.where((t) => t.id == id).firstOrNull;
  TaxOption? taxById(int? id) => taxes.where((t) => t.id == id).firstOrNull;
  Product? productById(int? id) =>
      products.where((p) => p.id == id).firstOrNull;
  CustomerOption? customerById(int? id) =>
      customers.where((c) => c.id == id).firstOrNull;
  WarehouseOption? warehouseById(int? id) =>
      warehouses.where((w) => w.id == id).firstOrNull;
  StaffUser? userById(int? id) => users.where((u) => u.id == id).firstOrNull;

  /// What [warehouseId] holds of [productId], in the stock (reference) unit.
  double stockOf(int productId, int warehouseId) => stocks
      .where((s) => s.productId == productId && s.warehouseId == warehouseId)
      .fold<double>(0, (sum, s) => sum + s.quantity);
}

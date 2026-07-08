class TaxExportItem {
  final int id;
  final String name;
  final double rate;
  final String? code;
  final bool isFixed;
  final bool isTaxOnTotal;
  final bool isEnabled;

  TaxExportItem({
    required this.id,
    required this.name,
    required this.rate,
    this.code,
    required this.isFixed,
    required this.isTaxOnTotal,
    required this.isEnabled,
  });

  factory TaxExportItem.fromJson(Map<String, dynamic> j) => TaxExportItem(
        id: j['id'] as int,
        name: j['name'] as String,
        rate: (j['rate'] as num).toDouble(),
        code: j['code'] as String?,
        isFixed: j['isFixed'] as bool,
        isTaxOnTotal: j['isTaxOnTotal'] as bool,
        isEnabled: j['isEnabled'] as bool,
      );
}

class ProductExportRow {
  final int id;
  final String name;
  final String? productGroupName;
  final String? code;
  final int? plu;
  final String? measurementUnit;
  final double cost;
  final double? markup;
  final double price;
  final bool isTaxInclusivePrice;
  final bool isPriceChangeAllowed;
  final bool isUsingDefaultQuantity;
  final bool isService;
  final bool isEnabled;
  final String? description;
  final double totalStock;
  final String? supplierName;
  final double reorderPoint;
  final double preferredQuantity;
  final bool isLowStockWarningEnabled;
  final double lowStockWarningQuantity;
  final String color;
  final int? rank;
  final int? ageRestriction;
  final double? lastPurchasePrice;
  final String? dateCreated;
  final String? dateUpdated;
  final List<String> barcodes;
  final List<TaxExportItem> taxes;
  final List<String> comments;

  ProductExportRow({
    required this.id,
    required this.name,
    this.productGroupName,
    this.code,
    this.plu,
    this.measurementUnit,
    required this.cost,
    this.markup,
    required this.price,
    required this.isTaxInclusivePrice,
    required this.isPriceChangeAllowed,
    required this.isUsingDefaultQuantity,
    required this.isService,
    required this.isEnabled,
    this.description,
    required this.totalStock,
    this.supplierName,
    required this.reorderPoint,
    required this.preferredQuantity,
    required this.isLowStockWarningEnabled,
    required this.lowStockWarningQuantity,
    required this.color,
    this.rank,
    this.ageRestriction,
    this.lastPurchasePrice,
    this.dateCreated,
    this.dateUpdated,
    required this.barcodes,
    required this.taxes,
    required this.comments,
  });

  factory ProductExportRow.fromJson(Map<String, dynamic> j) => ProductExportRow(
        id: j['id'] as int,
        name: j['name'] as String,
        productGroupName: j['productGroupName'] as String?,
        code: j['code'] as String?,
        plu: j['plu'] as int?,
        measurementUnit: j['measurementUnit'] as String?,
        cost: (j['cost'] as num).toDouble(),
        markup: (j['markup'] as num?)?.toDouble(),
        price: (j['price'] as num).toDouble(),
        isTaxInclusivePrice: j['isTaxInclusivePrice'] as bool,
        isPriceChangeAllowed: j['isPriceChangeAllowed'] as bool,
        isUsingDefaultQuantity: j['isUsingDefaultQuantity'] as bool,
        isService: j['isService'] as bool,
        isEnabled: j['isEnabled'] as bool,
        description: j['description'] as String?,
        totalStock: (j['totalStock'] as num).toDouble(),
        supplierName: j['supplierName'] as String?,
        reorderPoint: (j['reorderPoint'] as num).toDouble(),
        preferredQuantity: (j['preferredQuantity'] as num).toDouble(),
        isLowStockWarningEnabled: j['isLowStockWarningEnabled'] as bool,
        lowStockWarningQuantity: (j['lowStockWarningQuantity'] as num).toDouble(),
        color: j['color'] as String? ?? 'Transparent',
        rank: j['rank'] as int?,
        ageRestriction: j['ageRestriction'] as int?,
        lastPurchasePrice: (j['lastPurchasePrice'] as num?)?.toDouble(),
        dateCreated: j['dateCreated'] as String?,
        dateUpdated: j['dateUpdated'] as String?,
        barcodes: (j['barcodes'] as List<dynamic>).cast<String>(),
        taxes: (j['taxes'] as List<dynamic>)
            .map((t) => TaxExportItem.fromJson(t as Map<String, dynamic>))
            .toList(),
        comments: (j['comments'] as List<dynamic>).cast<String>(),
      );
}

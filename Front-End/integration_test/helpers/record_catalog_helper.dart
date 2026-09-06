/// `recordE2ECatalog` / `loadE2ECatalog` — the catalogue handoff between tests.
///
/// ```dart
/// // in 03_setup_catalog
/// await recordE2ECatalog(ctx);
///
/// // in 04_setup_stock
/// final catalogue = loadE2ECatalog();
/// for (final p in catalogue.products) { ... }
/// ```
///
/// ## Why a file and not just a shared context
///
/// Each numbered test is its OWN `flutter test` process against its own fresh
/// app boot — there is no in-memory state that survives from one to the next.
/// The suite already solves that for the company (Cypress writes it, the Flutter
/// tests read it) and for the customer; this is the same mechanism for the
/// catalogue.
///
/// 🚨 It is written under the COMPANY the terminal is linked to, exactly like
/// the customer block, because "the newest catalogue in the file" and "the
/// catalogue on this terminal" stop being the same thing the moment Cypress
/// provisions another company.
library;

import 'dart:convert';
import 'dart:io';

import '../config/test_config.dart';
import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// One product as `03_setup_catalog` left it.
class E2EProduct {
  const E2EProduct({
    required this.name,
    required this.code,
    this.price,
    this.cost,
    this.groupName,
    this.taxName,
    this.uom,
    this.isService = false,
    this.isToWeigh = false,
    this.barcode,
  });

  final String name;
  final String code;
  final double? price;
  final double? cost;
  final String? groupName;
  final String? taxName;

  /// The unit code — `pcs`, `kg`, `g`, `L`.
  ///
  /// Carried because it decides what STOCK is counted in: a weighed product is
  /// held in its category's reference unit, so a stock figure means nothing
  /// without it.
  final String? uom;

  final bool isService;
  final bool isToWeigh;
  final String? barcode;

  /// A service has no stock, so stock tests must skip it rather than fail on it.
  bool get takesStock => !isService;

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        if (price != null) 'price': price,
        if (cost != null) 'cost': cost,
        if (groupName != null) 'groupName': groupName,
        if (taxName != null) 'taxName': taxName,
        if (uom != null) 'uom': uom,
        'isService': isService,
        'isToWeigh': isToWeigh,
        if (barcode != null) 'barcode': barcode,
      };

  static E2EProduct fromJson(Map<String, dynamic> j) => E2EProduct(
        name: j['name'] as String,
        code: (j['code'] as String?) ?? '',
        price: (j['price'] as num?)?.toDouble(),
        cost: (j['cost'] as num?)?.toDouble(),
        groupName: j['groupName'] as String?,
        taxName: j['taxName'] as String?,
        uom: j['uom'] as String?,
        isService: (j['isService'] as bool?) ?? false,
        isToWeigh: (j['isToWeigh'] as bool?) ?? false,
        barcode: j['barcode'] as String?,
      );
}

/// Everything one catalogue run created.
class E2ECatalog {
  const E2ECatalog({
    required this.runTag,
    required this.products,
    this.groups = const [],
    this.taxName,
  });

  final String runTag;
  final List<E2EProduct> products;
  final List<String> groups;
  final String? taxName;

  /// The products a stock test can actually work with — services have none.
  List<E2EProduct> get stockable =>
      products.where((p) => p.takesStock).toList();
}

/// Writes everything [ctx] created into `pos-credentials.json`.
///
/// Nested under the linked company as a `catalogs` list, newest first — the same
/// shape the customer block uses, so one company can carry the history of every
/// run made against it.
Future<void> recordE2ECatalog(E2EContext ctx) async {
  final products = <E2EProduct>[
    for (final a in ctx.of('Product'))
      E2EProduct(
        name: a.name,
        code: a.code ?? '',
        price: a.extra['Price'] as double?,
        cost: a.extra['Cost'] as double?,
        groupName: a.extra['Group'] as String?,
        taxName: a.extra['Tax'] as String?,
        uom: a.extra['Uom'] as String?,
        isService: (a.extra['IsService'] as bool?) ?? false,
        isToWeigh: (a.extra['IsToWeigh'] as bool?) ?? false,
        barcode: ctx.barcodes[a.name],
      ),
  ];

  if (products.isEmpty) {
    step('Nothing to record — this run created no products');
    return;
  }

  final file = File(kCredentialsPath);
  final entries =
      (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  final company =
      entries.where((e) => e['companyId'] == ctx.company.companyId).firstOrNull;
  if (company == null) {
    throw StateError(
      'Cannot record a catalogue for company ${ctx.company.companyId} — it is '
      'not in ${file.absolute.path}',
    );
  }

  final existing = (company['catalogs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  company['catalogs'] = [
    {
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'runTag': kRunTag,
      'taxName': ctx.taxName,
      'groups': [for (final g in ctx.of('ProductGroup')) g.name],
      'products': [for (final p in products) p.toJson()],
    },
    ...existing,
  ];

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
  );

  step('Catalogue recorded to ${file.absolute.path} — '
      '${products.length} products under company ${ctx.company.companyId}');
}

/// The newest catalogue recorded against the company this terminal is LINKED to.
///
/// 🚨 The linked company, NOT the newest entry in the file, and the distinction
/// is the same one `loadLinkedCompany()` exists for. The terminal stays linked to
/// whichever company `01_login_new_company` last registered against, while
/// Cypress writes a NEW entry every time it provisions one — so the moment a
/// company is provisioned, "newest in the file" and "the company on this
/// machine" are different companies. Reading the newest would hand
/// `04_setup_stock` a product list belonging to a shop this till has never seen,
/// and it would stock the wrong company or fail somewhere unhelpful.
///
/// Pass [companyId] to pin it explicitly.
///
/// Throws rather than returning null, so a test that depends on a catalogue
/// fails where the problem actually is instead of several steps later on an
/// empty product list.
Future<E2ECatalog> loadE2ECatalog({int? companyId}) async {
  final file = File(kCredentialsPath);
  if (!file.existsSync()) {
    throw StateError('No credentials at ${file.absolute.path}');
  }

  final entries =
      (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  // Falls back to the newest entry only when the terminal is not registered at
  // all — the one case where "newest" is genuinely the right answer.
  final wanted = companyId ?? await linkedCompanyId();
  final company = wanted == null
      ? entries.firstOrNull
      : entries.where((e) => e['companyId'] == wanted).firstOrNull;

  final recorded = (company?['catalogs'] as List?)?.cast<Map<String, dynamic>>();
  if (recorded == null || recorded.isEmpty) {
    throw StateError(_noCatalogueMessage(file, entries, wanted));
  }

  final newest = recorded.first;
  return E2ECatalog(
    runTag: (newest['runTag'] as String?) ?? '',
    taxName: newest['taxName'] as String?,
    groups: ((newest['groups'] as List?) ?? const []).cast<String>(),
    products: ((newest['products'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(E2EProduct.fromJson)
        .toList(),
  );
}

/// Says WHICH of the three ways this went wrong, rather than "run 03 first".
///
/// The three are genuinely different problems with different fixes, and telling
/// them apart is the difference between a one-line fix and an afternoon:
///
///  * no company anywhere has one → 03 has never recorded, so re-run it;
///  * another company has one → this terminal is linked somewhere else;
///  * this company has one but it is empty → 03 failed before it recorded.
///
/// The first case is what a run of 03 from BEFORE the recording step existed
/// looks like — the products are really on the server and the run really passed,
/// which is exactly why "build one first" reads as wrong when you have just
/// watched it build one.
String _noCatalogueMessage(
  File file,
  List<Map<String, dynamic>> entries,
  int? wanted,
) {
  final withCatalogues = [
    for (final e in entries)
      if (((e['catalogs'] as List?) ?? const []).isNotEmpty)
        '${e['companyId']} (${((e['catalogs'] as List).first
                as Map<String, dynamic>)['runTag']})',
  ];

  final buffer = StringBuffer()
    ..writeln('No catalogue recorded for company '
        '${wanted ?? '(this terminal is not linked to one)'} in')
    ..writeln(file.absolute.path);

  if (withCatalogues.isEmpty) {
    buffer
      ..writeln('No company in that file has one at all.')
      ..writeln('If 03_setup_catalog has already passed on this machine, it ran '
          'BEFORE the recording step existed — the products are on the server, '
          'but nothing wrote them here. Re-run it:')
      ..writeln(
          '    flutter test integration_test/03_setup_catalog_test.dart -d windows');
  } else {
    buffer
      ..writeln('These companies DO have one: ${withCatalogues.join(', ')}')
      ..writeln('So 03 has run — against a different company than this terminal '
          'is linked to. Either re-link:')
      ..writeln(
          '    flutter test integration_test/01_login_new_company_test.dart -d windows')
      ..writeln('  (spends a seat), or re-run 03 against the company this '
          'terminal is on:')
      ..writeln(
          '    flutter test integration_test/03_setup_catalog_test.dart -d windows');
  }
  return buffer.toString();
}

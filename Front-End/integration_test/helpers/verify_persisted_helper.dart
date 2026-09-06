/// `verifyPersisted` — proves the rows this run created reached the SERVER, and
/// writes the manifest that lets SQL Server be asked the same question directly.
///
/// ```dart
/// await syncNow(tester, ctx.l);
/// await verifyPersisted(tester, ctx);
/// ```
///
/// ## Why this file exists at all
///
/// Three bugs in this suite's history produced a completely green run: a price
/// silently overwritten by the cost-based markup recalc, a product that reached
/// the database with `ProductGroupId NULL`, and a verification that matched the
/// products table BEHIND the dialog instead of the dialog itself. All three were
/// caught by querying SQL Server afterwards.
///
/// The rule that came out of it: **an assertion that can pass for the wrong
/// reason is worse than no assertion**, because it converts a silent data bug
/// into a green test. Every helper that writes a row therefore ends up here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/database/database_provider.dart';

import '../config/test_config.dart';
import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Asserts every row [ctx] recorded now carries a SERVER-ISSUED id.
///
/// 🚨 This is the check that distinguishes "the app accepted it" from "the
/// server has it", and the mechanism is worth knowing rather than trusting.
///
/// These screens are offline-first: a row created in Management is written
/// locally under a TEMPORARY NEGATIVE id with `syncStatus = 'pending_create'`,
/// and the push swaps in the id the server assigns. So:
///
/// * `id < 0`  → the row never left this terminal, whatever the UI said;
/// * `id > 0` and `syncStatus == 'synced'` → the server issued that id, which it
///   can only have done for a row it actually stored.
///
/// Asserting `id > 0` BEFORE a sync would therefore just be asserting that the
/// sync had already happened — which is why the caller runs [syncNow] first.
///
/// Call it after a sync. It is safe to call more than once.
Future<void> verifyPersisted(WidgetTester tester, E2EContext ctx) async {
  final db = ctx.container.read(appDatabaseProvider);
  final companyId = ctx.company.companyId;

  for (final artifact in ctx.artifacts) {
    switch (artifact.table) {
      case 'Tax':
        await _expectServerId(
          tester,
          artifact,
          () async => (await (db.select(db.taxesTable)
                    ..where((t) => t.companyId.equals(companyId))
                    ..orderBy([(t) => OrderingTerm.desc(t.id)]))
                  .get())
              .where((t) => t.name == artifact.name)
              .map((t) => (id: t.id, syncStatus: t.syncStatus))
              .toList(),
        );

      case 'ProductGroup':
        await _expectServerId(
          tester,
          artifact,
          () async => (await (db.select(db.productGroupsTable)
                    ..where((t) => t.companyId.equals(companyId))
                    ..orderBy([(t) => OrderingTerm.desc(t.id)]))
                  .get())
              .where((g) => g.name == artifact.name)
              .map((g) => (id: g.id, syncStatus: g.syncStatus))
              .toList(),
        );

      case 'Product':
        await _expectServerId(
          tester,
          artifact,
          () async => (await (db.select(db.productsTable)
                    ..where((t) => t.companyId.equals(companyId))
                    ..orderBy([(t) => OrderingTerm.desc(t.id)]))
                  .get())
              .where((p) => p.name == artifact.name)
              .map((p) => (id: p.id, syncStatus: p.syncStatus))
              .toList(),
        );

      case 'Barcode':
        // 🚨 Barcodes do NOT follow the negative-temp-id convention the other
        // three use. `barcodes` is keyed by a UUID `localId` and carries a
        // NULLABLE `serverId` — so "the server has it" is `serverId != null`,
        // not `id > 0`. Mapped onto the same shape below with -1 standing in for
        // "no server id yet", which fails the `id > 0` check exactly as an
        // unsynced row should.
        await _expectServerId(
          tester,
          artifact,
          () async => (await (db.select(db.barcodesTable)
                    ..where((t) => t.companyId.equals(companyId)))
                  .get())
              .where((b) => b.value == artifact.name)
              .map((b) => (id: b.serverId ?? -1, syncStatus: b.syncStatus))
              .toList(),
        );

      default:
        step('No local check for ${artifact.table} — manifest only');
    }
  }

  await writeRunManifest(ctx);
}

/// Waits for one artifact's row to carry a positive, synced id.
///
/// `waitUntil` rather than a bare `expect`, because the push finishes
/// asynchronously: the manual sync returns when the QUEUE is drained, and the
/// row's re-key can land a beat later. A bare assertion here would fail on a
/// slow network for a reason that has nothing to do with the code under test.
Future<void> _expectServerId(
  WidgetTester tester,
  E2EArtifact artifact,
  Future<List<({int id, String syncStatus})>> Function() rows,
) async {
  await waitUntil(
    tester,
    () async {
      final found = await rows();
      return found.isNotEmpty &&
          found.first.id > 0 &&
          found.first.syncStatus == 'synced';
    },
    describe: '${artifact.table} "${artifact.name}" is accepted by the server',
    timeout: const Duration(seconds: 180),
  );

  final row = (await rows()).first;
  step('Server holds ${artifact.table} "${artifact.name}" as id ${row.id}');
}

/// Writes what this run created, plus the SQL that checks it, to `e2e/output/`.
///
/// The in-app check above proves the server ISSUED an id. This is what lets the
/// row's actual COLUMNS be read back out of SQL Server — the only place a price
/// mangled by the markup recalc or a `ProductGroupId NULL` is visible, since
/// both of those are perfectly well-formed rows that the sync accepts happily.
///
/// The file is a run artifact, not a fixture: it is overwritten every run and
/// lives beside `pos-credentials.json`, which is already git-ignored.
Future<void> writeRunManifest(E2EContext ctx) async {
  if (ctx.artifacts.isEmpty) return;

  final manifest = {
    'runTag': kRunTag,
    'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
    'companyId': ctx.company.companyId,
    'companyName': ctx.company.companyName,
    'artifacts': [
      for (final a in ctx.artifacts)
        {
          'table': a.table,
          'name': a.name,
          if (a.code != null) 'code': a.code,
          if (a.extra.isNotEmpty) 'expected': a.extra,
        },
    ],
    'verificationSql': _sqlFor(ctx),
  };

  final file = File(
    kCredentialsPath.replaceFirst(
      RegExp(r'pos-credentials\.json$'),
      'e2e-run-manifest.json',
    ),
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));

  step('Run manifest written: ${file.absolute.path}');
  step('Verify in SQL Server with the query it carries under "verificationSql"');
}

/// Escapes the run tag for use inside a T-SQL `LIKE` pattern.
///
/// 🚨 `LIKE '%[E2E 09061412]%'` does NOT mean what it looks like. In T-SQL,
/// square brackets open a CHARACTER CLASS — so that pattern reads "any one of
/// the characters E, 2, space, 0, 9, 1, 4, 6" and matches almost every row in
/// the table. Verified against the live database: `'Zebra' LIKE '%[E2E ...]%'`
/// returns TRUE, because the default collation is case-insensitive and 'e' is
/// in the set.
///
/// A verification query built that way returns the whole company's catalogue and
/// passes no matter what the run actually wrote — the exact "assertion that can
/// pass for the wrong reason" this file exists to prevent, reintroduced in the
/// checker itself. `[[]` is the escape for a literal opening bracket; the
/// closing one needs none.
String _likeTag(String tag) => '[[]E2E $tag]';

/// The query that reads this run's rows back out of SQL Server.
///
/// Table names are SINGULAR, as the schema spells them — `Product`, `Tax`,
/// `ProductGroup` — not the plural Drift uses locally. Scoped to the run tag so
/// it returns this run's rows and not ten days of accumulated E2E data.
List<String> _sqlFor(E2EContext ctx) {
  final companyId = ctx.company.companyId;
  final tag = _likeTag(kRunTag);
  final sql = <String>[];

  if (ctx.of('Tax').isNotEmpty) {
    sql.add(
      'SELECT Id, Name, Code, Rate, IsEnabled FROM Tax '
      "WHERE CompanyId = $companyId AND Name LIKE '%$tag%';",
    );
  }
  if (ctx.of('ProductGroup').isNotEmpty) {
    sql.add(
      'SELECT Id, Name, ParentGroupId, Rank FROM ProductGroup '
      "WHERE CompanyId = $companyId AND Name LIKE '%$tag%';",
    );
  }
  if (ctx.of('Product').isNotEmpty) {
    // 🚨 ProductGroupId and Price are both selected on purpose. A product with
    // ProductGroupId NULL and a product priced at its cost are the two bugs this
    // suite has actually shipped, and neither is visible anywhere else.
    sql.add(
      'SELECT p.Id, p.Name, p.Code, p.Price, p.Cost, p.ProductGroupId, '
      'g.Name AS GroupName, p.IsService, p.IsToWeigh, t.Name AS TaxName '
      'FROM Product p '
      'LEFT JOIN ProductGroup g ON g.Id = p.ProductGroupId '
      'LEFT JOIN ProductTax pt ON pt.ProductId = p.Id '
      'LEFT JOIN Tax t ON t.Id = pt.TaxId '
      "WHERE p.CompanyId = $companyId AND p.Name LIKE '%$tag%';",
    );
  }
  if (ctx.of('Document').isNotEmpty) {
    // Matched on Number rather than the run tag: a Document carries no name to
    // stamp, and the number is the thing a receipt in the customer's hand
    // shows. `DocumentItem` is joined so the answer says what was actually sold.
    final numbers = ctx.of('Document').map((a) => "'${a.name}'").join(', ');
    sql.add(
      // `Price`, not `UnitPrice` — DocumentItem has no such column, and the
      // schema was checked rather than guessed. `Total` is selected beside it
      // because a line can be right on price and wrong on the money it booked.
      'SELECT d.Id, d.Number, d.Total, d.UserId, p.Name AS ProductName, '
      'di.Quantity, di.Price, di.Total AS LineTotal FROM Document d '
      'LEFT JOIN DocumentItem di ON di.DocumentId = d.Id '
      'LEFT JOIN Product p ON p.Id = di.ProductId '
      'WHERE d.CompanyId = $companyId AND d.Number IN ($numbers);',
    );
  }
  if (ctx.of('Barcode').isNotEmpty) {
    // Joined back to Product so the answer says WHICH product carries the code.
    // A barcode row that exists but hangs off the wrong product is a real
    // failure mode, and `SELECT Value` alone would report it as a pass.
    final values =
        ctx.of('Barcode').map((a) => "'${a.name}'").join(', ');
    sql.add(
      'SELECT b.Id, b.Value, b.ProductId, p.Name AS ProductName FROM Barcode b '
      'LEFT JOIN Product p ON p.Id = b.ProductId '
      'WHERE b.CompanyId = $companyId AND b.Value IN ($values);',
    );
  }
  return sql;
}

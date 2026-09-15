/// Drains the catalog import outbox to the server.
///
/// The XML import writes the local catalogue and queues every row
/// (`lib/product/catalog_import_local.dart`); this sends the rows to the
/// existing `/Products/ImportBulk` in small batches, from the sync's push phase.
///
/// **Retryable.** A row stays 'pending' until the server's answer for it is
/// written locally — in the same transaction that swaps its temp product id for
/// the real one. An offline till, a 500, a timeout or an app closed mid-request
/// leaves the row pending, and the next sync sends it again.
///
/// **Idempotent.** The server matches products and groups by NAME, so resending
/// a batch whose response was lost updates (or skips) what the first attempt
/// created rather than creating it twice — and reports the same product ids.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/product/catalog_import_local.dart';

class CatalogImportUploader {
  CatalogImportUploader({
    required this.db,
    required this.dio,
    this.budget = const Duration(seconds: 45),
    this.initialBatchSize = 100,
    this.maxBatchSize = 250,
    this.requestTimeout = const Duration(minutes: 2),
  }) : _batchSize = initialBatchSize;

  final AppDatabase db;
  final Dio dio;

  /// How long one sync may spend uploading. A large import must not hold the
  /// rest of the sync — sales, payments, voids — back for minutes; the notifier
  /// runs again straight away while [hasMoreWork] says there is more.
  final Duration budget;

  final int initialBatchSize;
  final int maxBatchSize;

  /// Per request, replacing the app-wide 10 s: the server imports a batch row
  /// by row, and a batch that is merely slow must not be abandoned and resent.
  final Duration requestTimeout;

  int _batchSize;

  /// Rows the next batch will carry. Halved after a timeout or a refused
  /// batch, doubled after a quick one, within 1…[maxBatchSize].
  int get batchSize => _batchSize;

  bool _hasMoreWork = false;

  /// True when the last [push] ran out of [budget] with rows still to send.
  bool get hasMoreWork => _hasMoreWork;

  static const _fastBatch = Duration(seconds: 4);
  static const _slowBatch = Duration(seconds: 20);

  /// Sends everything queued for [companyId], oldest import first, until the
  /// queue is empty or [budget] is spent.
  ///
  /// Throws when the server cannot be reached or fails — so the sync step
  /// reports it — with the rows left pending for the next run.
  Future<void> push(int companyId) async {
    _hasMoreWork = false;
    await _releaseInterruptedJobs(companyId);

    final jobs = await (db.select(db.catalogImportJobsTable)
          ..where((t) =>
              t.companyId.equals(companyId) &
              t.status.isIn(const ['importing', 'pending']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final deadline = DateTime.now().add(budget);

    for (final job in jobs) {
      try {
        if (!job.groupsSent) await _sendGroups(job);
        while (true) {
          final batch = await _nextBatch(job.id);
          if (batch.isEmpty) break;
          if (DateTime.now().isAfter(deadline)) {
            _hasMoreWork = true;
            return;
          }
          await _sendBatch(job, batch);
        }
      } catch (e) {
        await _recordFailure(job.id, e);
        rethrow;
      }
      await _completeIfDone(job.id);
    }
  }

  /// A job the app was still writing when it closed. Its committed chunks are
  /// consistent — each carried its products and their rows together — so what
  /// was written is uploaded; importing the file again queues the rest.
  Future<void> _releaseInterruptedJobs(int companyId) async {
    final stuck = await (db.select(db.catalogImportJobsTable)
          ..where((t) =>
              t.companyId.equals(companyId) & t.status.equals('importing')))
        .get();
    for (final job in stuck) {
      if (LocalCatalogImporter.activeJobs.contains(job.id)) continue;
      await (db.update(db.catalogImportJobsTable)
            ..where((t) => t.id.equals(job.id)))
          .write(const CatalogImportJobsTableCompanion(status: Value('pending')));
    }
  }

  /// The next rows to send, in file order. A row whose temp product was
  /// deleted on this till before it ever reached the server is cancelled, not
  /// sent — the operator removed it.
  Future<List<CatalogImportRowsTableData>> _nextBatch(String jobId) async {
    final rows = await (db.select(db.catalogImportRowsTable)
          ..where((t) => t.jobId.equals(jobId) & t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.rowIndex)])
          ..limit(_batchSize))
        .get();

    final temps = {
      for (final r in rows)
        if ((r.localProductId ?? 0) < 0) r.localProductId!,
    };
    if (temps.isEmpty) return rows;

    final p = db.productsTable;
    final alive = {
      for (final r in await (db.selectOnly(p)
            ..addColumns([p.id])
            ..where(p.id.isIn(temps) &
                p.syncStatus.isNotIn(const ['pending_delete'])))
          .get())
        r.read(p.id)!,
    };
    final gone = temps.difference(alive);
    if (gone.isEmpty) return rows;

    await (db.update(db.catalogImportRowsTable)
          ..where((t) =>
              t.jobId.equals(jobId) &
              t.status.equals('pending') &
              t.localProductId.isIn(gone)))
        .write(const CatalogImportRowsTableCompanion(
      status: Value('cancelled'),
      message: Value('deleted on this device before it reached the server'),
    ));
    return _nextBatch(jobId);
  }

  // ── requests ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await dio.post<dynamic>(
      path,
      data: body,
      options: Options(sendTimeout: requestTimeout, receiveTimeout: requestTimeout),
    );
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// The file's group skeleton, once per job, before its products — so the
  /// groups the rows land in carry the file's colours, ranks and nesting.
  Future<void> _sendGroups(CatalogImportJobsTableData job) async {
    final groups = (jsonDecode(job.groupsJson) as List).cast<Map<String, dynamic>>();
    if (groups.isNotEmpty) {
      try {
        final res = await _post('/ProductGroups/ImportBulk', {
          'companyId': job.companyId,
          'skipDuplicates': !job.mergeDuplicates,
          'mergeDuplicates': job.mergeDuplicates,
          'rows': groups,
        });
        final refs = res['groups'];
        if (refs is List) {
          await db.transaction(() => _adoptGroupIds(job.companyId, {
                for (final ref in refs.whereType<Map>())
                  if (ref['name'] is String && ref['id'] is num)
                    ref['name'] as String: (ref['id'] as num).toInt(),
              }));
        }
      } on DioException catch (e) {
        if (_retryable(e)) rethrow;
        // Refused: the product rows still carry their full group paths, and
        // the server builds the groups from those.
        debugPrint('catalog import: group skeleton refused — ${_describe(e)}');
      }
    }
    await (db.update(db.catalogImportJobsTable)..where((t) => t.id.equals(job.id)))
        .write(const CatalogImportJobsTableCompanion(groupsSent: Value(true)));
  }

  Future<void> _sendBatch(
      CatalogImportJobsTableData job, List<CatalogImportRowsTableData> rows) async {
    final started = DateTime.now();
    final Map<String, dynamic> res;
    try {
      res = await _post('/Products/ImportBulk', {
        'companyId': job.companyId,
        'skipDuplicates': !job.mergeDuplicates,
        'mergeDuplicates': job.mergeDuplicates,
        // Never a stock document: a resent batch would write a second one.
        'documentType': 'none',
        'rows': [for (final r in rows) jsonDecode(r.payload)],
      });
    } on DioException catch (e) {
      final tooSlow = e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (tooSlow) _batchSize = math.max(1, _batchSize ~/ 2);
      if (_retryable(e)) rethrow;

      // Refused outright (400, 413 …). One malformed row fails a whole batch
      // at model binding, so halve until it stands alone, then fail only it.
      if (rows.length > 1) {
        _batchSize = math.max(1, rows.length ~/ 2);
        return;
      }
      await _applyRefusal(rows.single, _describe(e));
      return;
    }

    final took = DateTime.now().difference(started);
    if (took < _fastBatch) {
      _batchSize = math.min(maxBatchSize, _batchSize * 2);
    } else if (took > _slowBatch) {
      _batchSize = math.max(1, _batchSize ~/ 2);
    }
    await _applyResult(rows, res);
  }

  /// Offline, timed out, dropped, or failing server-side: not the rows' fault,
  /// so they are sent again. Auth and licence answers are retried too — they
  /// clear with a sign-in, not by editing the file.
  static bool _retryable(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return true;
    return status >= 500 ||
        status == 401 ||
        status == 403 ||
        status == 404 ||
        status == 408 ||
        status == 429;
  }

  static String _describe(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return '${data['message']}';
      final status = e.response?.statusCode;
      if (status != null) return 'HTTP $status';
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The server took too long to respond',
        _ => 'The server could not be reached',
      };
    }
    return '$e';
  }

  // ── answers ───────────────────────────────────────────────────────────────

  /// Writes the server's answer for a batch: every row's outcome, the real id
  /// for each product created offline, and the imported barcodes and taxes
  /// handed over to the next pull — all in one transaction, so a crash can
  /// never leave a row marked done whose product still holds its temp id.
  Future<void> _applyResult(
      List<CatalogImportRowsTableData> rows, Map<String, dynamic> res) async {
    final reported = res['rows'];
    // An API older than per-row results says only "done": those rows are
    // matched by name after the pull instead (see [reconcileByName]).
    final perRow = reported is List;
    final byIndex = <int, Map<dynamic, dynamic>>{
      if (reported is List)
        for (final r in reported.whereType<Map>())
          if (r['index'] is num) (r['index'] as num).toInt(): r,
    };

    final toReal = <int, int>{};
    final settled = <int>{};
    final refused = <int, String>{};
    var refetch = false;

    await db.transaction(() async {
      await db.batch((b) {
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          final answer = byIndex[i];
          final outcome = answer?['outcome'] as String?;
          final message = answer?['message'] as String?;
          final failed = outcome == 'error';
          b.update(
            db.catalogImportRowsTable,
            CatalogImportRowsTableCompanion(
              status: Value(failed ? 'failed' : 'done'),
              outcome: Value(outcome),
              message: Value(message),
            ),
            where: (t) =>
                t.jobId.equals(row.jobId) & t.rowIndex.equals(row.rowIndex),
          );

          final local = row.localProductId;
          if (local == null || !perRow) continue;
          if (failed) {
            if (local < 0) refused[local] = message ?? 'Refused by the server';
            continue;
          }
          final serverId = (answer?['productId'] as num?)?.toInt();
          if (local < 0 && serverId != null) {
            toReal[local] = serverId;
            settled.add(serverId);
            // The server already had it and left it alone, so a delta pull will
            // never send it: this till must fetch it to show the server's copy.
            if (outcome == 'skipped') refetch = true;
          } else if (local > 0) {
            settled.add(local);
          }
        }
      });

      await _adoptProductIds(toReal);
      await _settle(settled);
      for (final e in refused.entries) {
        await (db.update(db.productsTable)
              ..where((t) => t.id.equals(e.key) & t.syncStatus.equals(kPendingImport)))
            .write(ProductsTableCompanion(
          syncStatus: const Value('sync_failed'),
          syncError: Value(e.value),
        ));
      }
      if (rows.isNotEmpty) {
        await (db.update(db.catalogImportJobsTable)
              ..where((t) => t.id.equals(rows.first.jobId)))
            .write(const CatalogImportJobsTableCompanion(lastError: Value(null)));
      }
    });

    if (refetch) {
      await (db.delete(db.syncMetaTable)..where((t) => t.entity.equals('products')))
          .go();
    }
  }

  Future<void> _applyRefusal(CatalogImportRowsTableData row, String message) =>
      db.transaction(() async {
        await (db.update(db.catalogImportRowsTable)
              ..where((t) =>
                  t.jobId.equals(row.jobId) & t.rowIndex.equals(row.rowIndex)))
            .write(CatalogImportRowsTableCompanion(
          status: const Value('failed'),
          outcome: const Value('error'),
          message: Value(message),
        ));
        final local = row.localProductId;
        if (local != null && local < 0) {
          await (db.update(db.productsTable)
                ..where((t) => t.id.equals(local) & t.syncStatus.equals(kPendingImport)))
              .write(ProductsTableCompanion(
            syncStatus: const Value('sync_failed'),
            syncError: Value(message),
          ));
        }
      });

  /// Swaps temp product ids for the server's, everywhere they are referenced.
  ///
  /// When the real product is already on this till (a pull brought it before
  /// the answer did) the temp copy is simply dropped; otherwise the temp row is
  /// re-keyed in place, keeping what the operator sees until the pull refreshes
  /// it. A temp product the operator edited meanwhile keeps that edit queued.
  Future<void> _adoptProductIds(Map<int, int> toReal) async {
    if (toReal.isEmpty) return;
    final p = db.productsTable;
    final alreadyHere = {
      for (final r in await (db.selectOnly(p)
            ..addColumns([p.id])
            ..where(p.id.isIn(toReal.values)))
          .get())
        r.read(p.id)!,
    };

    // A (product, tax) pair the real id already holds would collide on the key.
    for (final e in toReal.entries) {
      await db.customUpdate(
        'DELETE FROM product_taxes WHERE product_id = ? AND tax_id IN '
        '(SELECT tax_id FROM product_taxes WHERE product_id = ?)',
        variables: [Variable.withInt(e.key), Variable.withInt(e.value)],
        updates: {db.productTaxesTable},
        updateKind: UpdateKind.delete,
      );
    }
    await db.remapProductIds(toReal);

    final dropped = [
      for (final e in toReal.entries)
        if (alreadyHere.contains(e.value)) e.key,
    ];
    if (dropped.isNotEmpty) {
      await (db.delete(p)..where((t) => t.id.isIn(dropped))).go();
    }

    final rekey = [
      for (final e in toReal.entries)
        if (!alreadyHere.contains(e.value)) e,
    ];
    for (var start = 0; start < rekey.length; start += 400) {
      final slice = rekey.sublist(start, math.min(start + 400, rekey.length));
      await db.customUpdate(
        'UPDATE products SET id = CASE id '
        '${List.filled(slice.length, 'WHEN ? THEN ?').join(' ')} END, '
        "sync_status = CASE WHEN sync_status = '$kPendingImport' THEN 'synced' "
        "ELSE 'pending_update' END, "
        'sync_error = NULL '
        'WHERE id IN (${List.filled(slice.length, '?').join(', ')})',
        variables: [
          for (final e in slice) ...[Variable.withInt(e.key), Variable.withInt(e.value)],
          for (final e in slice) Variable.withInt(e.key),
        ],
        updates: {p},
        updateKind: UpdateKind.update,
      );
    }
  }

  /// The imported barcodes and product taxes of acknowledged products become
  /// ordinary synced rows, which the next pull replaces with the server's own —
  /// including a barcode the server refused because another product holds it.
  Future<void> _settle(Set<int> productIds) async {
    if (productIds.isEmpty) return;
    await (db.update(db.barcodesTable)
          ..where((t) =>
              t.syncStatus.equals(kPendingImport) & t.productId.isIn(productIds)))
        .write(const BarcodesTableCompanion(syncStatus: Value('synced')));
    await (db.update(db.productTaxesTable)
          ..where((t) =>
              t.syncStatus.equals(kPendingImport) & t.productId.isIn(productIds)))
        .write(const ProductTaxesTableCompanion(syncStatus: Value('synced')));
  }

  /// Swaps temp group ids for the server's, matched by name — names are unique
  /// per company on the server.
  Future<void> _adoptGroupIds(int companyId, Map<String, int> idByName) async {
    if (idByName.isEmpty) return;
    final byKey = {
      for (final e in idByName.entries) e.key.trim().toLowerCase(): e.value,
    };
    final temps = await (db.select(db.productGroupsTable)
          ..where((t) =>
              t.companyId.equals(companyId) &
              t.id.isSmallerThanValue(0) &
              t.syncStatus.equals(kPendingImport)))
        .get();
    for (final temp in temps) {
      final realId = byKey[temp.name.trim().toLowerCase()];
      if (realId == null) continue;
      await db.remapProductGroupId(temp.id, realId);
      final here = await (db.selectOnly(db.productGroupsTable)
            ..addColumns([db.productGroupsTable.id])
            ..where(db.productGroupsTable.id.equals(realId)))
          .getSingleOrNull();
      if (here != null) {
        await (db.delete(db.productGroupsTable)..where((t) => t.id.equals(temp.id)))
            .go();
      } else {
        await (db.update(db.productGroupsTable)..where((t) => t.id.equals(temp.id)))
            .write(ProductGroupsTableCompanion(
          id: Value(realId),
          syncStatus: const Value('synced'),
        ));
      }
    }
  }

  Future<void> _recordFailure(String jobId, Object error) async {
    try {
      await db.customUpdate(
        'UPDATE catalog_import_jobs SET attempts = attempts + 1, last_error = ? '
        'WHERE id = ?',
        variables: [Variable.withString(_describe(error)), Variable.withString(jobId)],
        updates: {db.catalogImportJobsTable},
        updateKind: UpdateKind.update,
      );
    } catch (_) {/* the original failure is the one worth reporting */}
  }

  Future<void> _completeIfDone(String jobId) async {
    final job = await (db.select(db.catalogImportJobsTable)
          ..where((t) => t.id.equals(jobId)))
        .getSingleOrNull();
    // 'importing': still being written here, so more rows may yet come.
    if (job == null || job.status != 'pending') return;
    final left = countAll();
    final pending = await (db.selectOnly(db.catalogImportRowsTable)
          ..addColumns([left])
          ..where(db.catalogImportRowsTable.jobId.equals(jobId) &
              db.catalogImportRowsTable.status.equals('pending')))
        .map((r) => r.read(left) ?? 0)
        .getSingle();
    if (pending > 0) return;
    await (db.update(db.catalogImportJobsTable)..where((t) => t.id.equals(jobId)))
        .write(CatalogImportJobsTableCompanion(
      status: const Value('completed'),
      completedAt: Value(DateTime.now().toUtc()),
      lastError: const Value(null),
    ));
  }

  /// Runs after the pull. Matches by name whatever the server acknowledged
  /// without an id — an older API with no per-row results, or a group only a
  /// product row created — now that the server's rows are on this till.
  Future<void> reconcileByName(int companyId) async {
    await db.transaction(() async {
      final g = db.productGroupsTable;
      final hasTempGroups = await (db.selectOnly(g)
            ..addColumns([g.id])
            ..where(g.companyId.equals(companyId) &
                g.id.isSmallerThanValue(0) &
                g.syncStatus.equals(kPendingImport))
            ..limit(1))
          .getSingleOrNull();
      if (hasTempGroups != null) {
        final realGroups = <String, int>{};
        for (final r in await (db.selectOnly(g)
              ..addColumns([g.id, g.name])
              ..where(g.companyId.equals(companyId) & g.id.isBiggerThanValue(0))
              ..orderBy([OrderingTerm.asc(g.id)]))
            .get()) {
          realGroups.putIfAbsent(r.read(g.name)!, () => r.read(g.id)!);
        }
        await _adoptGroupIds(companyId, realGroups);
      }

      final rows = await (db.select(db.catalogImportRowsTable)
            ..where((t) =>
                t.companyId.equals(companyId) &
                t.status.equals('done') &
                t.outcome.isNull() &
                t.localProductId.isSmallerThanValue(0)))
          .get();
      if (rows.isEmpty) return;

      final p = db.productsTable;
      final realByKey = <String, int>{};
      for (final r in await (db.selectOnly(p)
            ..addColumns([p.id, p.name])
            ..where(p.companyId.equals(companyId) &
                p.id.isBiggerThanValue(0) &
                p.syncStatus.isNotIn(const ['pending_delete']))
            ..orderBy([OrderingTerm.asc(p.id)]))
          .get()) {
        realByKey.putIfAbsent(r.read(p.name)!.trim().toLowerCase(), () => r.read(p.id)!);
      }
      final toReal = <int, int>{
        for (final r in rows)
          if (realByKey[r.nameKey] != null) r.localProductId!: realByKey[r.nameKey]!,
      };
      await _adoptProductIds(toReal);
      await _settle(toReal.values.toSet());
    });
  }
}

/// Where the latest import for a company stands — for the import screen.
class CatalogImportProgress {
  const CatalogImportProgress({
    required this.jobId,
    required this.fileName,
    required this.completed,
    required this.pending,
    required this.done,
    required this.failed,
    required this.lastError,
  });

  final String jobId;
  final String? fileName;
  final bool completed;
  final int pending;
  final int done;
  final int failed;
  final String? lastError;

  int get total => pending + done + failed;
}

Stream<CatalogImportProgress?> watchLatestCatalogImport(
        AppDatabase db, int companyId) =>
    db
        .customSelect(
          'SELECT j.id, j.file_name, j.status, j.last_error, '
          "SUM(CASE WHEN r.status = 'pending' THEN 1 ELSE 0 END) AS pending, "
          "SUM(CASE WHEN r.status = 'done' THEN 1 ELSE 0 END) AS done, "
          "SUM(CASE WHEN r.status = 'failed' THEN 1 ELSE 0 END) AS failed "
          'FROM catalog_import_jobs j '
          'LEFT JOIN catalog_import_rows r ON r.job_id = j.id '
          'WHERE j.company_id = ? '
          'GROUP BY j.id ORDER BY j.created_at DESC, j.rowid DESC LIMIT 1',
          variables: [Variable.withInt(companyId)],
          readsFrom: {db.catalogImportJobsTable, db.catalogImportRowsTable},
        )
        .watch()
        .map((rows) {
      if (rows.isEmpty) return null;
      final r = rows.first;
      return CatalogImportProgress(
        jobId: r.read<String>('id'),
        fileName: r.readNullable<String>('file_name'),
        completed: r.read<String>('status') == 'completed',
        pending: r.readNullable<int>('pending') ?? 0,
        done: r.readNullable<int>('done') ?? 0,
        failed: r.readNullable<int>('failed') ?? 0,
        lastError: r.readNullable<String>('last_error'),
      );
    });

/// The rows the server refused in one import, as "name — reason".
Future<List<String>> loadRefusedCatalogImportRows(AppDatabase db, String jobId,
    {int limit = 200}) async {
  final rows = await (db.select(db.catalogImportRowsTable)
        ..where((t) => t.jobId.equals(jobId) & t.status.equals('failed'))
        ..orderBy([(t) => OrderingTerm.asc(t.rowIndex)])
        ..limit(limit))
      .get();
  return [
    for (final r in rows)
      '${(jsonDecode(r.payload) as Map)['name']} — ${r.message ?? ''}',
  ];
}

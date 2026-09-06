/// The context object every helper flow takes, and the rules it plays by.
///
/// This is the Dart twin of the plain object a Cypress spec builds before it
/// calls its modules:
///
/// ```js
/// const context = { email, password, souscripteur }
/// Login(context)
/// CreateLotArrivage(context)
/// ```
///
/// A test file defines its data once, hands it to a sequence of helpers, and
/// stays readable as a recipe rather than a script of taps.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/l10n/app_localizations.dart';

import '../support/e2e_support.dart';

/// Everything the helpers share: who is signed in, and what has been built.
///
/// It is deliberately MUTABLE. Each helper records what it created, so the next
/// one can use it without the test file having to shuttle values by hand — the
/// dependency chain the modular rule asks for:
///
/// ```dart
/// await createTax(tester, ctx);        // records ctx.taxName
/// await createProduct(tester, ctx);    // uses it, unasked
/// ```
///
/// ## How a helper resolves a dependency
///
/// Three levels, highest first:
///
/// 1. **The explicit argument.** `createProduct(taxName: 'VAT 7%')` — the test
///    is asserting a specific relationship, so nothing may override it.
/// 2. **The context.** Whatever an earlier helper in this run recorded.
/// 3. **The UI's first real option.** Nothing was named and nothing was built,
///    so the helper takes what the company already has (`pickDropdownAt`).
///
/// Level 3 is what lets `createProduct` stand alone. Level 1 is what lets a
/// test prove a relationship. Both are needed, and mixing them up silently is
/// the failure this ordering exists to prevent — so every helper PRINTS which
/// level it used.
class E2EContext {
  E2EContext({
    this.taxName,
    this.taxCode,
    this.taxRatePercent,
    this.groupName,
    this.parentGroupName,
    this.productName,
  });

  // ── Session ────────────────────────────────────────────────────────────────

  /// The company this terminal is signed in to, as `loginToCompany` resolved it.
  late E2ECompany company;

  /// The running app's own container, from the shipping `ProviderScope`.
  ///
  /// Taken from the real tree rather than built by the test, so it stays valid
  /// across every screen and what it reports is what the cashier is looking at.
  late ProviderContainer container;

  /// The app's translations, as of the last navigation.
  ///
  /// 🚨 Never cache this across a screen change. The app ships en/fr/ar and the
  /// locale can change MID-RUN — this suite starts in whatever language the
  /// company was left in and switches during setup. Helpers call [refreshL10n]
  /// after every navigation for exactly that reason.
  late AppLocalizations l;

  /// Re-reads the translations from the tree. Call after any navigation.
  void refreshL10n(WidgetTester tester) => l = l10nOf(tester);

  // ── What this run has built ────────────────────────────────────────────────
  //
  // Written by the helper that creates each thing, read by the helpers that
  // depend on it. `null` means "not built in this run" — which is the signal to
  // fall back to the UI's first available option.

  /// Tax name as it appears in the picker, e.g. `VAT 20% [E2E 09061412]`.
  String? taxName;

  /// Tax code. Unique per company — `UQ_Tax_Code_PerCompany`.
  String? taxCode;

  /// The rate that was typed, as a string, e.g. `'20'`.
  String? taxRatePercent;

  /// The most recently created product group.
  String? groupName;

  /// Its parent, when one was created above it.
  String? parentGroupName;

  /// The most recently created product.
  String? productName;

  /// Barcode by product name, as `addBarcode` generated it.
  ///
  /// Kept per product rather than as a single value because the verification
  /// pass asserts the EXACT code came back on the RIGHT product — a check that
  /// only means something if the codes are told apart.
  final Map<String, String> barcodes = {};

  /// Every row this run created, in creation order — the manifest the
  /// SQL Server verification pass reads.
  final List<E2EArtifact> artifacts = [];

  /// Records a created row and returns it.
  E2EArtifact record(E2EArtifact artifact) {
    artifacts.add(artifact);
    step('Recorded ${artifact.table}: ${artifact.name}');
    return artifact;
  }

  /// Everything created against one SQL Server table.
  Iterable<E2EArtifact> of(String table) =>
      artifacts.where((a) => a.table == table);
}

/// One row this run created, named so SQL Server can be asked about it.
///
/// The point of carrying [table] and [name] rather than just a label: the
/// verification pass turns these straight into queries against the real
/// database, which is the only check that catches a row the UI reported as
/// saved but the server never received.
class E2EArtifact {
  const E2EArtifact({
    required this.table,
    required this.name,
    this.code,
    this.extra = const {},
  });

  /// The SQL Server table, singular as the schema spells it: `Product`, `Tax`,
  /// `ProductGroup`, `Barcode`.
  final String table;

  /// The `Name` column's value — carries the run tag, so it is unique.
  final String name;

  /// The `Code` column's value, where the table has one.
  final String? code;

  /// Columns worth asserting beyond identity: price, cost, group, rate.
  final Map<String, Object?> extra;

  @override
  String toString() => '$table("$name")';
}

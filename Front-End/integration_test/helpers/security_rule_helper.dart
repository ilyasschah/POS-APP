/// `setSecurityLevel` — moves one permission between Cashier and Admin.
///
/// ```dart
/// final was = await setSecurityLevel(
///     tester, ctx, SecurityKeys.reprintReceipt, SecurityLevel.adminOnly);
/// ```
///
/// ## The model, in one table
///
/// | `User.accessLevel` | what the guard does |
/// |---|---|
/// | `0` Admin | **universal access — the key is never even looked at** |
/// | `1` Cashier | allowed only where `SecurityKey.level == 0` |
///
/// Plus two fail-secure rules: no signed-in user denies everything, and an
/// UNKNOWN key denies too (unknown = admin-only).
///
/// 🚨 The first row is why a test signed in as the Admin can never observe a
/// denial. Locking a key and then finding the screen still opens proves nothing
/// about the rule — it proves the account is an admin. Seeing a refusal needs a
/// cashier at the till, which needs a PIN for that user on this device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/database/database_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// The two levels a rule can hold, named after what they mean.
enum SecurityLevel {
  /// `0` — a cashier may use it.
  cashier,

  /// `1` — admins only.
  adminOnly;

  int get value => this == SecurityLevel.cashier ? 0 : 1;

  static SecurityLevel of(int raw) =>
      raw == 0 ? SecurityLevel.cashier : SecurityLevel.adminOnly;
}

/// Sets [keyName] to [level] and returns the level it held BEFORE.
///
/// The previous level is returned so a caller can put it back — these rules are
/// company-wide, and a test that locks a screen and walks away has changed the
/// shop for every terminal and every later test.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
Future<SecurityLevel> setSecurityLevel(
  WidgetTester tester,
  E2EContext ctx,
  String keyName,
  SecurityLevel level,
) async {
  await ensureManagementSection(tester, ctx.l, ctx.l.securityRules);

  final before = await _levelOf(ctx, keyName);
  if (before == level) {
    step('$keyName is already ${level.name}');
    return before;
  }

  // 🚨 The tile is found by its raw key in a TOOLTIP, not by the label on it.
  // The visible text is `securityKeyLabel(context, name)` — translated, and one
  // of forty near-identical rule names — while the tooltip carries the raw key
  // (`Order.Void`, `SalesHistory.Receipt`). That makes this finder immune to
  // both the language and a relabelling.
  if (find.byTooltip(keyName).evaluate().isEmpty) {
    // The list is long and virtualised, so a row below the fold is not in the
    // tree at all — filtering is what brings it in.
    await searchList(tester, securityRuleQuery(keyName));
    await pumpFor(tester, const Duration(seconds: 1));
  }

  await waitFor(
    tester,
    find.byTooltip(keyName),
    timeout: const Duration(seconds: 30),
    because: 'No security rule tile for "$keyName". The rule set is seeded by '
        'the server, so a missing row means the first sync has not landed.',
  );

  // 🚨 The control is a SIBLING of the label, not an ancestor of it.
  //
  // `_RuleTile` builds `Row(children: [Flexible(Tooltip(Text(label))), SizedBox,
  // SegmentedButton])`. So `find.ancestor(of: tooltip, matching: SegmentedButton)`
  // asks for a segmented button that CONTAINS the tooltip — and nothing does.
  // It matched nothing, and the `.first` chained onto it turned that into an
  // internal `'_found != null'` assertion from deep inside the matcher rather
  // than a readable "no segment found".
  //
  // The innermost Row enclosing the tooltip IS the tile, and the control lives
  // inside it. `visitAncestorElements` walks child-upward, so `.first` is the
  // closest Row — the tile's own, not some wider one holding every rule.
  //
  // Same shape as the payment-type switches, where the label and the `Switch`
  // are siblings too.
  final tile = enclosingRow(
    tester,
    find.byTooltip(keyName),
    describe: 'the "$keyName" rule tooltip',
  );

  // 🚨 Tapped by ICON, never by the segment's label. `_RuleTile` renders
  // `label: widget.dense ? null : Text(roleCashier)` — on a narrow window the
  // segments are ICON-ONLY, so a text finder works on a wide monitor and finds
  // nothing on a tablet. The icons are present in both modes.
  final icon = level == SecurityLevel.adminOnly
      ? Icons.lock_outline
      : Icons.groups_outlined;

  final segment = find.descendant(of: tile, matching: find.byIcon(icon));
  if (segment.evaluate().isEmpty) {
    throw TestFailure(
      'No ${level.name} segment on the "$keyName" rule tile.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  await tapVisible(tester, segment.first);

  // 🚨 Wait for the SUCCESS message, and do not settle for the Drift row.
  //
  // `_updateLevel` writes to Drift OPTIMISTICALLY — before it calls the server —
  // and REVERTS that write if the server rejects. So reading the local level
  // straight after the tap tells you only that the tap landed; it says the new
  // value even on a request that is about to fail. Two other outcomes are
  // possible and neither is success: "Update failed" (rejected, row reverted)
  // and "Saved offline. Will sync when connected." (queued, server unaware).
  //
  // The success snackbar is the only one of the three that means the server
  // took it.
  await waitFor(
    tester,
    find.textContaining(_updatedFragment(ctx)),
    timeout: const Duration(seconds: 60),
    because: 'No confirmation that "$keyName" was updated. Look for "Update '
        'failed" (the server rejected it) or "Saved offline" (it was only '
        'queued) on screen.',
  );

  expect(
    find.text(ctx.l.savedOfflineWillSync),
    findsNothing,
    reason: 'The rule change was queued offline, so the SERVER does not have '
        'it — a later run reading the rules back would see the old level.',
  );

  // Now the local row means something: the revert window has passed.
  await waitUntil(
    tester,
    () async => await _levelOf(ctx, keyName) == level,
    describe: '"$keyName" settles at ${level.name}',
    timeout: const Duration(seconds: 30),
  );

  ctx.record(E2EArtifact(
    table: 'SecurityKey',
    name: keyName,
    extra: {'Level': level.value, 'Was': before.value},
  ));
  step('Security rule: $keyName ${before.name} -> ${level.name}');
  return before;
}

/// The level [keyName] currently holds, straight from the local rule set.
///
/// Public so a caller can ASSERT a restore landed rather than trust it — a
/// silent failure there leaves a company carrying a permission a test invented.
Future<SecurityLevel> securityLevelOf(E2EContext ctx, String keyName) =>
    _levelOf(ctx, keyName);

Future<SecurityLevel> _levelOf(E2EContext ctx, String keyName) async {
  final db = ctx.container.read(appDatabaseProvider);
  final rows = await (db.select(db.securityKeysTable)
        ..where((t) => t.companyId.equals(ctx.company.companyId))
        ..where((t) => t.name.equals(keyName)))
      .get();

  if (rows.isEmpty) {
    throw TestFailure(
      'No security rule named "$keyName" on company ${ctx.company.companyId}. '
      'The full key set is seeded server-side, so an empty result means the '
      'rules have not reached this terminal yet.',
    );
  }
  return SecurityLevel.of(rows.first.level);
}

/// The part of the success snackbar that is NOT the rule's name.
///
/// The message is built as "<rule> updated.", where the rule is the TRANSLATED
/// label — which this helper deliberately does not know, because it works in raw
/// keys. So the placeholder is rendered with a sentinel no real label contains,
/// and the longest surviving fragment is the invariant wording.
///
/// 🚨 Not `replaceAll(' ', '')`. That would work only because the English tail
/// happens to be a single word: French renders "mis à jour." and stripping its
/// spaces gives "misàjour.", which matches nothing on screen. Splitting on the
/// sentinel keeps the real wording in every language.
String _updatedFragment(E2EContext ctx) {
  const sentinel = '<<RULE>>';
  return ctx.l
      .securityRuleUpdated(sentinel)
      .split(sentinel)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .reduce((a, b) => a.length >= b.length ? a : b);
}

/// A search term that narrows the rule list towards [keyName].
///
/// The search box filters on the VISIBLE label, not the raw key, so the raw key
/// is a poor query. Its last dotted segment is usually a word the label also
/// contains (`SalesHistory.Receipt` → `Receipt`), which is enough to shorten a
/// forty-row list.
String securityRuleQuery(String keyName) =>
    keyName.contains('.') ? keyName.split('.').last : keyName;

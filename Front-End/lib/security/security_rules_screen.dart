import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_dropdown.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/security/security_key_model.dart';
import 'package:pos_app/security/security_key_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Who may use each part of the POS — one rule per line, two levels each.
///
/// Split out of `UsersScreen`'s second tab. The two screens answer different
/// questions ("who works here" vs "what may they touch"), they are opened by
/// different people on different days, and the tab bar cost both of them their
/// header — which is where the house scaffold puts the search bar and the
/// primary action. Both still sit behind the same `Management.Security` key:
/// splitting the SCREEN is not splitting the permission.
///
/// The old tab was a fixed two-column `FractionallySizedBox(widthFactor: 0.5)`
/// grid under a `Colors.blue.shade600` header — two columns on a 7" tablet and
/// on a 27" monitor alike, and a hardcoded blue in every theme. The column
/// count is now derived from the width the section actually gets, and every
/// colour comes from the theme.

/// Display label for a security key. The keys themselves are the server's
/// identity for the rule and must never be translated — only the label is.
String securityKeyLabel(BuildContext context, String key) {
  final l10n = AppLocalizations.of(context);
  switch (key) {
    case 'Management':
      return l10n.management;
    case 'Settings':
      return l10n.settings;
    case 'BusinessDay.Close':
      return l10n.endOfDay;
    case 'UserProfile':
      return l10n.userProfileLower;
    case 'ShiftManagement':
      return l10n.shiftManagement;
    case 'CashMovement':
      return l10n.cashInOut;
    case 'FloorPlans.Design':
      return l10n.designFloorPlans;
    case 'FloorPlans.View':
      return l10n.floorPlanTables;
    case 'Bookings':
      return l10n.posBookings;
    case 'Bookings.History':
      return l10n.bookingHistory;
    case 'Order.All':
      return l10n.viewAllOpenOrders;
    case 'Order.Void':
      return l10n.voidOrder;
    case 'Order.Item.Void':
      return l10n.voidItem;
    case 'Order.Estimate':
      return l10n.createEstimate;
    case 'Order.Estimate.Clear':
      return l10n.clearEstimate;
    case 'Order.Transfer':
      return l10n.transferOrder;
    case 'Payment.Discount':
      return l10n.applyDiscount;
    case 'Invoices.Delete':
      return l10n.deleteDocument;
    case 'Refund':
      return l10n.posRefund;
    case 'Payment.TaxOverride':
      return l10n.overrideTaxes;
    case 'SalesHistory':
      return l10n.viewSalesHistory;
    case 'SalesHistory.Receipt':
      return l10n.reprintReceipt;
    case 'CreditPayments':
      return l10n.creditPayments;
    case 'StartingCash':
      return l10n.startingCashLower;
    case 'CashDrawer.Open':
      return l10n.openCashDrawerLower;
    case 'Stock.Control.NegativeQuantity':
      return l10n.zeroStockQuantitySale;
    case 'Management.Dashboard':
      return l10n.dashboard;
    case 'Management.Documents':
      return l10n.documents;
    case 'Management.Products':
      return l10n.products;
    case 'Management.ProductGroups':
      return l10n.productGroups;
    case 'Management.Stock':
      return l10n.stock;
    case 'Management.Warehouses':
      return l10n.warehouses;
    case 'Management.Reporting':
      return l10n.reporting;
    case 'Management.Customers':
      return l10n.customersSuppliersLower;
    case 'Management.Promotions':
      return l10n.promotions;
    case 'Management.Security':
      return l10n.usersSecurityLower;
    case 'Management.PaymentTypes':
      return l10n.paymentTypesLower;
    case 'Management.Countries':
      return l10n.countriesLabel;
    case 'Management.Currencies':
      return l10n.currencies;
    case 'Management.TaxRates':
      return l10n.taxRatesLower;
    case 'Management.Company':
      return l10n.myCompanyLower;
    case 'Management.VoidReasons':
      return l10n.voidReasonsLower;
    case 'Management.Stock.QuickInventory':
      return l10n.quickInventory;
    case 'Management.Stock.ShowCostPrices':
      return l10n.viewCostPrices;
    case 'Management.LoyaltyCards':
      return l10n.loyaltyCardsLower;
    default:
      return key;
  }
}

/// Display label for the four security-rule category ids. The ids are the
/// grouping map's identity — only the label is translated.
String _categoryLabel(BuildContext context, String id) {
  final l10n = AppLocalizations.of(context);
  switch (id) {
    case 'General':
      return l10n.generalLabel;
    case 'Sales':
      return l10n.sales;
    case 'Management':
      return l10n.management;
    case 'Stock':
      return l10n.stock;
    default:
      return id;
  }
}

IconData _categoryIcon(String id) {
  switch (id) {
    case 'General':
      return Icons.apps;
    case 'Sales':
      return Icons.point_of_sale;
    case 'Management':
      return Icons.admin_panel_settings;
    case 'Stock':
      return Icons.inventory_2;
    default:
      return Icons.vpn_key;
  }
}

/// Which section a rule belongs to. The order of the tests matters: the two
/// Stock sub-rules are `Management.*` names that belong with Stock.
String _categoryOf(String key) {
  if (key == 'Management.Stock.QuickInventory' ||
      key == 'Management.Stock.ShowCostPrices') {
    return 'Stock';
  }
  if (key.startsWith('Management.') && key != 'Management') return 'Management';
  if (key == 'Management' ||
      key == 'Settings' ||
      key == 'BusinessDay.Close' ||
      key == 'UserProfile' ||
      key == 'ShiftManagement' ||
      key == 'CashMovement' ||
      key == 'FloorPlans.Design' ||
      key == 'FloorPlans.View' ||
      key == 'Bookings' ||
      key == 'Bookings.History') {
    return 'General';
  }
  return 'Sales';
}

/// Section order on screen, stated once so it cannot drift from the grouping.
const _kCategoryOrder = ['General', 'Sales', 'Management', 'Stock'];

class SecurityRulesScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const SecurityRulesScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<SecurityRulesScreen> createState() =>
      _SecurityRulesScreenState();
}

class _SecurityRulesScreenState extends ConsumerState<SecurityRulesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Matches the TRANSLATED label first, then the raw key.
  ///
  /// The raw key is searched too because it is what every other surface calls
  /// the rule — the seeder, `SecurityKeys`, a support conversation — so typing
  /// `CashDrawer` has to find "open cash drawer" even in French.
  bool _matches(BuildContext context, SecurityKeyModel k, String q) {
    if (q.isEmpty) return true;
    return securityKeyLabel(context, k.name).toLowerCase().contains(q) ||
        k.name.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncKeys = ref.watch(allSecurityKeysProvider);
    final company = ref.watch(selectedCompanyProvider);

    return IlyassListScaffold(
      title: l10n.securityRules,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _searchCtrl,
        singleLine: true,
        hintText: l10n.actionSearch,
        chips: const [],
        sectionsBuilder: (_) => const [],
        onQueryChanged: (v) => setState(() => _query = v),
        onClearAll: () {
          _searchCtrl.clear();
          setState(() => _query = '');
        },
      ),
      body: asyncKeys.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.errorLoadingSecurityRules(e.toString()))),
        data: (keys) {
          if (company == null) {
            return Center(child: Text(l10n.noCompanySelectedShort));
          }
          if (keys.isEmpty) {
            return Center(child: Text(l10n.noSecurityRules));
          }

          final q = _query.trim().toLowerCase();
          final grouped = <String, List<SecurityKeyModel>>{
            for (final c in _kCategoryOrder) c: <SecurityKeyModel>[],
          };
          for (final k in keys) {
            if (!_matches(context, k, q)) continue;
            grouped[_categoryOf(k.name)]!.add(k);
          }
          // Alphabetical by what is actually printed, so the eye can scan it —
          // the API returns them in seed order, which reads as random.
          for (final list in grouped.values) {
            list.sort((a, b) => securityKeyLabel(context, a.name)
                .toLowerCase()
                .compareTo(securityKeyLabel(context, b.name).toLowerCase()));
          }

          final shown = grouped.values.fold<int>(0, (n, l) => n + l.length);
          if (shown == 0) return _EmptySearch(query: _query.trim());

          final adminOnly = keys.where((k) => k.level == 1).length;

          // A reading view, not a data table: cap the width so a 2560px monitor
          // does not strand a label a metre from its own control.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxReadableWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (q.isEmpty)
                    _Legend(total: keys.length, adminOnly: adminOnly),
                  for (final entry in grouped.entries)
                    if (entry.value.isNotEmpty)
                      _CategorySection(
                        categoryId: entry.key,
                        rules: entry.value,
                        companyId: company.id,
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The one thing an operator has to understand before touching this screen:
/// what the two levels mean, and how much of the till is already locked.
/// Hidden while searching — by then they know.
class _Legend extends StatelessWidget {
  const _Legend({required this.total, required this.adminOnly});

  final int total;
  final int adminOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: context.infoColor),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).securityRulesIntro,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)
                      .securityRulesSummary(total, adminOnly),
                  style:
                      theme.textTheme.labelLarge?.copyWith(color: cs.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).noResultsForFilters,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '"$query"',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryId,
    required this.rules,
    required this.companyId,
  });

  final String categoryId;
  final List<SecurityKeyModel> rules;
  final int companyId;

  /// Narrowest a rule tile may get before a column is dropped. Sized off the
  /// widest thing in one — the role picker at its natural width in the longest
  /// language ("Administrateur", ~220) plus a label long enough to read ("view
  /// all open orders"). Inside the readable-width cap that works out to two
  /// columns at most: the ceiling comes from the math, not a hardcoded `min`.
  static const double _minTileWidth = 400;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final restricted = rules.where((r) => r.level == 1).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(_categoryIcon(categoryId), size: 18, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _categoryLabel(context, categoryId),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                restricted == 0
                    ? '${rules.length}'
                    : AppLocalizations.of(context)
                        .securityCategoryCount(rules.length, restricted),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Math-based wrapping: the column count comes from the width this
            // section actually got, never from a device breakpoint.
            final columns = math.max(
              1,
              ((constraints.maxWidth + _gap) / (_minTileWidth + _gap)).floor(),
            );
            final tileWidth =
                (constraints.maxWidth - _gap * (columns - 1)) / columns;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final rule in rules)
                  SizedBox(
                    // The key is the rule's own name so a test can measure one
                    // tile and pin the column count to the width it was given.
                    key: ValueKey('security-rule-${rule.name}'),
                    width: tileWidth,
                    child: _RuleTile(rule: rule, companyId: companyId),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// One rule: what it governs, and who may do it.
///
/// The role is a dropdown: the current answer stays visible in every tile, in
/// its own colour, and the long translated role words live in the menu instead
/// of squeezing the rule label beside them.
class _RuleTile extends ConsumerStatefulWidget {
  const _RuleTile({
    required this.rule,
    required this.companyId,
  });

  final SecurityKeyModel rule;
  final int companyId;

  @override
  ConsumerState<_RuleTile> createState() => _RuleTileState();
}

class _RuleTileState extends ConsumerState<_RuleTile> {
  bool _isLoading = false;

  Future<void> _updateLevel(int newLevel) async {
    final oldLevel = widget.rule.level;
    final db = ref.read(appDatabaseProvider);

    // Optimistic write → Drift StreamProvider re-emits immediately, UI is instant.
    await db.into(db.securityKeysTable).insertOnConflictUpdate(
          SecurityKeysTableCompanion(
            companyId: Value(widget.companyId),
            name: Value(widget.rule.name),
            level: Value(newLevel),
          ),
        );

    setState(() => _isLoading = true);
    try {
      await ref.read(userManagementProvider).updateSecurityKey(
            widget.companyId,
            widget.rule.name,
            newLevel,
          );
      // No invalidate needed — Drift stream already emitted the new value.
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).securityRuleUpdated(
            securityKeyLabel(context, widget.rule.name),
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response == null) {
        // No connectivity — keep the optimistic Drift write and queue it.
        await db.into(db.pendingUserOpsTable).insert(
              PendingUserOpsTableCompanion(
                operation: const Value('update_security_key'),
                companyId: Value(widget.companyId),
                payload: Value(
                  jsonEncode({'name': widget.rule.name, 'level': newLevel}),
                ),
              ),
            );
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            AppLocalizations.of(context).savedOfflineWillSync,
          );
        }
      } else {
        // Server rejected — revert the optimistic Drift write.
        await db.into(db.securityKeysTable).insertOnConflictUpdate(
              SecurityKeysTableCompanion(
                companyId: Value(widget.companyId),
                name: Value(widget.rule.name),
                level: Value(oldLevel),
              ),
            );
        if (mounted) {
          final msg = e.response?.data?['message'] as String? ??
              AppLocalizations.of(context).updateFailed;
          showAppSnackbar(context, ref, msg, isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final adminOnly = widget.rule.level == 1;
    final pickerStyle = theme.textTheme.labelLarge?.copyWith(
      color: adminOnly ? context.dangerColor : cs.primary,
      fontWeight: FontWeight.w600,
    );
    final pickerWidth = _pickerWidth(
      context,
      pickerStyle,
      [l10n.roleCashier, l10n.roleAdmin],
    );

    final label = Tooltip(
      // The raw key, for anyone matching this screen against the docs.
      message: widget.rule.name,
      child: Text(
        securityKeyLabel(context, widget.rule.name),
        style: theme.textTheme.bodyMedium,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final picker = Tooltip(
      // What the current answer means, which the one word cannot say.
      message: adminOnly
          ? l10n.securityLevelAdminHint
          : l10n.securityLevelCashierHint,
      child: SizedBox(
        width: pickerWidth,
        child: IlyassDropdown<int>(
          dense: true,
          value: widget.rule.level,
          items: [
            IlyassDropdownItem(
              value: 0,
              label: l10n.roleCashier,
              icon: Icons.groups_outlined,
            ),
            IlyassDropdownItem(
              value: 1,
              label: l10n.roleAdmin,
              icon: Icons.lock_outline,
            ),
          ],
          prefixIcon: adminOnly ? Icons.lock_outline : Icons.groups_outlined,
          textStyle: pickerStyle,
          onChanged: _isLoading
              ? null
              : (next) {
                  if (next != null && next != widget.rule.level) {
                    _updateLevel(next);
                  }
                },
        ),
      ),
    );

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        // A locked rule is readable at a glance from across the grid, without
        // reading a single label.
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: adminOnly
              ? context.dangerColor.withValues(alpha: 0.35)
              : cs.outlineVariant,
        ),
      ),
      // Math-based, like the grid around it: the picker sits beside the label
      // only while the label keeps a readable width next to it, and drops under
      // the label below that. Side by side on a phone-width tile squeezed the
      // label to nothing and still pushed the picker out of the tile.
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth - pickerWidth - 12 >= _minLabelWidth) {
            // 🚨 The label is the ONLY flexible child: an operator may lose
            // the end of a rule name, never the answer they came to change.
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: label),
                const SizedBox(width: 12),
                picker,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 8),
              Align(alignment: AlignmentDirectional.centerEnd, child: picker),
            ],
          );
        },
      ),
    );
  }

  /// Narrowest the rule label may get beside the picker before the picker
  /// moves underneath it.
  static const double _minLabelWidth = 140;

  /// The field around the words: leading role icon, trailing arrow, padding.
  static const double _pickerChrome = 124;

  /// The picker's width, from its longest option in the current language and
  /// text size.
  ///
  /// 🚨 Never a fixed number, and never the dropdown's own natural width. A
  /// fixed 150/178 fit "Admin" and scrolled "Administrateur" out of its own
  /// field — a dropdown field does not ellipsize. Left to size itself, the
  /// dropdown takes its MENU's generous width (~400px in French), wider than a
  /// phone-width tile.
  static double _pickerWidth(
    BuildContext context,
    TextStyle? style,
    List<String> options,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final option in options) {
      final painter = TextPainter(
        text: TextSpan(text: option, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest.ceilToDouble() + _pickerChrome;
  }
}

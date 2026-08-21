import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/product/product_search.dart';

/// The product search field + scope buttons, shared by the POS menu and the
/// Products management screen.
///
/// Extracted from `menu_screen`, where it was inline. The two screens filter the
/// same catalogue with the same four scopes, and the codebase has already paid
/// for one divergent copy of shared behaviour (backlog item 24 — `saveAndSuspend`
/// carried its own copy of the order save and silently duplicated orders). One
/// widget + one predicate (`productMatchesSearch`) is what stops that repeating.
///
/// Everything that differs between the two callers is a parameter: the POS
/// hides the scope buttons behind `Menu.ShowSearchOptions` and submits to the
/// barcode handler, while the Products screen always shows them and has nothing
/// to submit to.
class ProductSearchBar extends StatelessWidget {
  const ProductSearchBar({
    super.key,
    required this.controller,
    required this.query,
    required this.scope,
    required this.onQueryChanged,
    required this.onScopeChanged,
    required this.hintText,
    this.onSubmitted,
    this.showScopeButtons = true,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 8),
    this.trailing,
  });

  final TextEditingController controller;

  /// The live query. Passed in rather than read off [controller] so the caller
  /// owns the state (the POS keeps it in a Riverpod provider, the Products
  /// screen in local widget state) and the clear button can rebuild.
  final String query;

  /// One of [ProductSearchScope]'s values.
  final String scope;

  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final bool showScopeButtons;
  final EdgeInsetsGeometry padding;

  /// Optional widget after the scope buttons (e.g. a result count).
  final Widget? trailing;

  static const Map<String, IconData> _scopeIcons = {
    ProductSearchScope.allFields: PhosphorIconsRegular.asterisk,
    ProductSearchScope.barcode: PhosphorIconsRegular.barcode,
    ProductSearchScope.code: PhosphorIconsRegular.hash,
    ProductSearchScope.name: PhosphorIconsRegular.tag,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const PhosphorIcon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 20,
                ),
                fillColor: cs.surfaceContainer,
                filled: true,
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const PhosphorIcon(
                          PhosphorIconsRegular.x,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
              onChanged: onQueryChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          if (showScopeButtons) ...[
            const SizedBox(width: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in ProductSearchScope.all)
                    Tooltip(
                      message: productSearchScopeLabel(context, mode),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onScopeChanged(mode),
                        child: Container(
                          // 44×44 minimum touch target — these are finger-sized
                          // on a 10" tablet, not mouse-sized.
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 36,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scope == mode
                                ? cs.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PhosphorIcon(
                            _scopeIcons[mode] ?? PhosphorIconsRegular.tag,
                            size: 20,
                            color: scope == mode
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

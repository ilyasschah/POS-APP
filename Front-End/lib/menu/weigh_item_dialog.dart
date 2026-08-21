import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/menu/quantity_keypad_dialog.dart';
import 'package:pos_app/scale/scale_service.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// Asks for the weight of a to-weigh product, the way Odoo does.
///
/// With a scale configured this shows the live reading and one big confirm
/// button, so the common case is put-it-down-and-tap. Without one — which is
/// every Android tablet, since [kScaleSupported] is Windows-only — it falls
/// straight through to the decimal keypad rather than blocking the sale.
///
/// Returns the quantity in the PRODUCT's unit, already snapped to that unit's
/// rounding, or null if the cashier backs out.
Future<double?> showWeighItemDialog(
  BuildContext context,
  WidgetRef ref, {
  required String itemName,
  required int uomId,
  required double unitPrice,
  required String currencySymbol,
}) async {
  final unit = uomById(uomId);
  final scaleOn = kScaleSupported && ref.read(scaleConfigProvider).enabled;

  // No scale on this platform, or none configured: the keypad IS the flow, so
  // go there directly instead of showing a dialog that can only say "no scale".
  if (!scaleOn) {
    // Returned exactly as typed — see the note in menu_screen's quantity
    // button. `initialQuantity` is the unit's step purely as a sensible
    // starting figure (0.001 kg, 1 pcs), not a constraint on what may be typed.
    return showQuantityKeypad(
      context,
      itemName: itemName,
      initialQuantity: unit.rounding,
      unit: unit.code,
    );
  }

  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WeighItemDialog(
      itemName: itemName,
      uomId: uomId,
      unitPrice: unitPrice,
      currencySymbol: currencySymbol,
    ),
  );
}

class _WeighItemDialog extends ConsumerWidget {
  final String itemName;
  final int uomId;
  final double unitPrice;
  final String currencySymbol;

  const _WeighItemDialog({
    required this.itemName,
    required this.uomId,
    required this.unitPrice,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final unit = uomById(uomId);

    // Snapped on the way in: a scale reporting 0.4999999996 kg must confirm as
    // 0.500, and the same figure has to reach both the line and stock.
    final reading = ref.watch(scaleReadingProvider);
    final raw = reading.value;
    final weight =
        raw == null ? 0.0 : snapToRounding(raw.weight, unit.rounding);

    // A reading of exactly zero is an empty pan, not a sale — confirm stays
    // disabled so a mis-tap cannot add a free line. An unsettled reading is
    // shown but not confirmable, which is what stops a cashier banking the
    // number mid-swing.
    final canConfirm = weight > 0 && (raw?.stable ?? false);

    // The parser never converts, so a scale streaming grams against a
    // kg-priced product would silently charge 1000×. Surface it rather than
    // guessing what the operator meant.
    final scaleUnit = raw?.unit;
    final mismatch = scaleUnit != null &&
        scaleUnit.toLowerCase() != unit.code.toLowerCase();

    return AlertDialog(
      title: Text(l10n.weighItem),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(itemName,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              '$currencySymbol ${unitPrice.toStringAsFixed(2)} / ${unit.code}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Center(
              child: switch (reading) {
                AsyncError(:final error) => Text(
                    error is ScaleException ? error.message : l10n.scaleReadFailed,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                AsyncData() => Text(
                    formatQuantity(weight, uomId),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: canConfirm
                          ? context.successColor
                          : context.warningColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                _ => Text(
                    l10n.placeOnScale,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
              },
            ),
            if (canConfirm) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '$currencySymbol ${(weight * unitPrice).toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
            if (mismatch) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: context.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.scaleUnitMismatch(scaleUnit, unit.code),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.warningColor),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        // Always available, even with a working scale: a jammed pan, or an item
        // too big for it, must not stop the cashier from selling.
        TextButton(
          onPressed: () async {
            final typed = await showQuantityKeypad(
              context,
              itemName: itemName,
              initialQuantity: weight > 0 ? weight : unit.rounding,
              unit: unit.code,
            );
            if (typed != null && context.mounted) {
              Navigator.pop(context, typed);
            }
          },
          child: Text(l10n.enterQuantity),
        ),
        FilledButton(
          onPressed: canConfirm ? () => Navigator.pop(context, weight) : null,
          child: Text(l10n.useThisWeight),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../core/breakpoints.dart';
import '../core/glass.dart';
import '../core/theme.dart';
import '../core/typography.dart';

/// Asks before something that cannot be taken back. Resolves true only when
/// the operator chose [confirmLabel].
///
/// Both buttons say what they do — "Discard" / "Keep editing", never
/// "OK" / "Cancel" — so the choice reads without the question above it.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final palette = context.palette;
      final confirmColor = destructive ? palette.negative : palette.accent;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxDialogWidth),
          child: GlassCard.overlay(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.headline(palette.primaryText)),
                const SizedBox(height: 10),
                Text(message, style: AppText.body(palette.dim(0.8))),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          foregroundColor: palette.dim(0.85),
                        ),
                        child: Text(cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          backgroundColor: confirmColor,
                          foregroundColor: AppTheme.onAccent(confirmColor),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

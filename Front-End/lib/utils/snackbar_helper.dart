import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';

/// Shows a premium overlay toast, respecting [SettingKeys.messageDuration]
/// and [SettingKeys.messagePosition] ('Top' or 'Bottom').
void showAppSnackbar(
  BuildContext context,
  WidgetRef ref,
  String message, {
  bool isError = false,
}) {
  final settings = ref.read(appSettingsProvider);
  final duration =
      int.tryParse(settings[SettingKeys.messageDuration] ?? '3') ?? 3;
  final position = settings[SettingKeys.messagePosition] ?? 'Bottom';

  _insertToast(context, message, isError: isError, duration: duration, position: position);
}

/// Call-site variant that doesn't need a [WidgetRef] — pass the values you
/// already have (e.g. from a SecurityGuard that already read the settings).
void showAppSnackbarRaw(
  BuildContext context,
  String message, {
  bool isError = false,
  int duration = 3,
  String position = 'Bottom',
}) {
  _insertToast(context, message, isError: isError, duration: duration, position: position);
}

void _insertToast(
  BuildContext context,
  String message, {
  required bool isError,
  required int duration,
  required String position,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PremiumToast(
      message: message,
      isError: isError,
      duration: duration,
      position: position,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

// ─────────────────────────────────────────────────────────────────────────────

class _PremiumToast extends StatefulWidget {
  final String message;
  final bool isError;
  final int duration;
  final String position;
  final VoidCallback onDismiss;

  const _PremiumToast({
    required this.message,
    required this.isError,
    required this.duration,
    required this.position,
    required this.onDismiss,
  });

  @override
  State<_PremiumToast> createState() => _PremiumToastState();
}

class _PremiumToastState extends State<_PremiumToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;
  bool _dismissed = false;

  bool get _isBottom =>
      widget.position.toLowerCase() == 'bottom';

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 220),
    );

    // Slide in from the right regardless of vertical position.
    _slide = Tween<Offset>(
      begin: const Offset(1.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();
    _timer = Timer(Duration(seconds: widget.duration), _dismiss);
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _timer?.cancel();
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isError
        ? const Color(0xFFEF4444) // red-500
        : const Color(0xFF22C55E); // green-500
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: _isBottom ? null : 32,
      bottom: _isBottom ? 32 : null,
      right: 32,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, minWidth: 280),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.45 : 0.14,
                      ),
                      blurRadius: 28,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.20 : 0.06,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2530) : Colors.white,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left accent strip
                          Container(width: 4, color: accentColor),
                          // Content
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 14, 12, 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(
                                      widget.isError
                                          ? Icons.error_outline_rounded
                                          : Icons.check_circle_outline_rounded,
                                      color: accentColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.message,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.45,
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _dismiss,
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.40),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

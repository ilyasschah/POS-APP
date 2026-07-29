import 'package:flutter/material.dart';

import '../core/glass.dart';
import '../core/screen_state.dart';
import '../core/theme.dart';
import '../core/typography.dart';

/// Renders the right view for a [ScreenState]: a spinner on first load, a
/// retryable error card when there's nothing to show, and otherwise the data.
///
/// A failed *refresh* that still has data falls through to [builder] — the
/// caller is expected to show a [RefreshErrorBanner] above it.
class ScreenStateBuilder<T> extends StatelessWidget {
  const ScreenStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
  });

  final ScreenState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) return const LoadingView();
    if (state.hasError && !state.hasData) {
      return ErrorView(message: state.error!, onRetry: onRetry);
    }
    if (state.hasData) return builder(context, state.data as T);
    return const SizedBox.shrink();
  }
}

/// Centered spinner for a screen's very first load.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.padding = const EdgeInsets.only(top: 64)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

/// Full-screen failure state: warning icon, message and a Retry action, in a
/// glass card. Shown only when there is no data to fall back on.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 40,
                color: palette.warning,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body(palette.primaryText),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Non-destructive banner shown when a *refresh* fails but stale data is still
/// on screen — the data stays visible instead of being replaced by an error.
class RefreshErrorBanner extends StatelessWidget {
  const RefreshErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: palette.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Showing the last loaded data — couldn't refresh. $message",
              style: AppText.caption(palette.primaryText),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Neutral "nothing here" state for an empty (but successful) result.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: palette.dim(0.35)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body(palette.dim(0.6)),
          ),
        ],
      ),
    );
  }
}

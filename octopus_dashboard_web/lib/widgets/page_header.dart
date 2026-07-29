import 'package:flutter/material.dart';

import '../core/glass.dart';
import '../core/theme.dart';
import '../core/typography.dart';

/// Shared screen header: optional eyebrow, title, and trailing actions.
///
/// Also hosts the manual refresh affordance. Pull-to-refresh doesn't map onto
/// desktop browsers, so every list screen keeps a visible refresh button.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const [],
    this.onRefresh,
    this.isRefreshing = false,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final VoidCallback? onRefresh;

  /// Spins the refresh icon while a background refresh is in flight.
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!, style: AppText.eyebrow(palette.dim(0.6))),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: AppText.title(palette.primaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ...actions,
          if (onRefresh != null) ...[
            if (actions.isNotEmpty) const SizedBox(width: 8),
            GlassPill(
              tooltip: 'Refresh',
              onTap: onRefresh,
              padding: const EdgeInsets.all(10),
              child: _RefreshIcon(
                isRefreshing: isRefreshing,
                color: palette.primaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefreshIcon extends StatefulWidget {
  const _RefreshIcon({required this.isRefreshing, required this.color});

  final bool isRefreshing;
  final Color color;

  @override
  State<_RefreshIcon> createState() => _RefreshIconState();
}

class _RefreshIconState extends State<_RefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isRefreshing) _controller.repeat();
  }

  @override
  void didUpdateWidget(_RefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRefreshing && _controller.isAnimating) {
      // Let the current turn finish so the icon doesn't stop mid-rotation.
      _controller.animateTo(1).whenComplete(() {
        if (mounted && !widget.isRefreshing) _controller.stop();
        if (mounted) _controller.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh_rounded, size: 18, color: widget.color),
    );
  }
}

/// Search box shared by the Products and Stock screens.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: AppText.body(palette.primaryText),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: palette.dim(0.5),
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: palette.dim(0.6),
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.controlRadius),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }
}

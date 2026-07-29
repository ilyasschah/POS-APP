import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/user.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'reset_password_dialog.dart';
import 'users_controller.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _resetPassword(
    BuildContext context,
    WidgetRef ref,
    StaffUser user,
  ) async {
    final didReset = await showResetPasswordDialog(context, user);
    if (didReset != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset for ${user.displayName}.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersProvider);
    final tier = LayoutTier.watch(context);
    final reload = ref.read(usersProvider.notifier).load;

    return Padding(
      padding: Layout.pagePadding(tier),
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'User Management',
              onRefresh: reload,
              isRefreshing: state.isRefreshing,
            ),
            if (state.hasError && state.hasData)
              RefreshErrorBanner(message: state.error!, onRetry: reload),
            Expanded(
              child: ScreenStateBuilder<List<StaffUser>>(
                state: state,
                onRetry: reload,
                builder: (context, users) {
                  if (users.isEmpty) {
                    return const EmptyView(
                      icon: Icons.people_outline_rounded,
                      message: 'No staff accounts found.',
                    );
                  }
                  return ListPanel(
                    itemCount: users.length,
                    itemBuilder: (context, index) => _UserRow(
                      user: users[index],
                      onResetPassword: () =>
                          _resetPassword(context, ref, users[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onResetPassword});

  final StaffUser user;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListRow(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  style: AppText.bodyStrong(palette.primaryText).weighted(700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.roleName,
                        style: AppText.caption(palette.dim(0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(isEnabled: user.isEnabled),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onResetPassword,
            tooltip: 'Reset password',
            icon: Icon(
              Icons.vpn_key_rounded,
              size: 20,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green "Active" / red "Disabled".
///
/// Reads `isEnabled` directly — the server has no `isBlocked` field, so
/// there's nothing to invert here.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isEnabled ? palette.positive : palette.negative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isEnabled ? 'Active' : 'Disabled',
        style: AppText.style(size: 11, weight: 700, color: color),
      ),
    );
  }
}

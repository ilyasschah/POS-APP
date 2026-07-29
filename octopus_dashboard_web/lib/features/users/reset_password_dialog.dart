import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/breakpoints.dart';
import '../../core/constants.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/user.dart';
import 'users_controller.dart';

/// Opens the admin password-reset form. Returns true when a reset succeeded.
Future<bool?> showResetPasswordDialog(BuildContext context, StaffUser user) {
  final tier = LayoutTier.watch(context);

  if (tier.prefersDialog) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxDialogWidth),
          child: GlassCard.overlay(
            padding: const EdgeInsets.all(24),
            child: ResetPasswordForm(user: user),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: GlassCard.overlay(
          padding: const EdgeInsets.all(20),
          child: ResetPasswordForm(user: user),
        ),
      ),
    ),
  );
}

class ResetPasswordForm extends ConsumerStatefulWidget {
  const ResetPasswordForm({super.key, required this.user});

  final StaffUser user;

  @override
  ConsumerState<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends ConsumerState<ResetPasswordForm> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onChanged);
    _confirmController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _password => _passwordController.text;
  String get _confirm => _confirmController.text;

  bool get _isLongEnough => _password.length >= AppConfig.minPasswordLength;
  bool get _matches => _password == _confirm;

  /// Only complain about a mismatch once the user has typed something to
  /// confirm.
  bool get _showMismatch => _confirm.isNotEmpty && !_matches;

  bool get _canSubmit => _isLongEnough && _matches && !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(usersProvider.notifier)
          .resetPassword(userId: widget.user.id, newPassword: _password);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.isCancelled) return;
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'Could not reset the password: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reset password for ${widget.user.displayName}',
            style: AppText.headline(palette.primaryText),
          ),
          const SizedBox(height: 20),
          _PasswordField(
            label: 'New Password',
            controller: _passwordController,
            obscure: !_showPassword,
            enabled: !_isSubmitting,
            onToggleVisibility: () =>
                setState(() => _showPassword = !_showPassword),
          ),
          if (_password.isNotEmpty && !_isLongEnough) ...[
            const SizedBox(height: 6),
            Text(
              'Must be at least ${AppConfig.minPasswordLength} characters.',
              style: AppText.caption(palette.dim(0.6)),
            ),
          ],
          const SizedBox(height: 14),
          _PasswordField(
            label: 'Confirm Password',
            controller: _confirmController,
            obscure: !_showPassword,
            enabled: !_isSubmitting,
            onSubmitted: _submit,
          ),
          if (_showMismatch) ...[
            const SizedBox(height: 6),
            Text(
              "Passwords don't match",
              style: AppText.caption(palette.negative),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: AppText.caption(palette.negative).copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: palette.dim(0.8),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppTheme.onAccent(palette.accent),
                            ),
                          )
                        : const Text('Reset'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.enabled,
    this.onToggleVisibility,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final bool enabled;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption(palette.dim(0.8)).weighted(600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          style: AppText.body(palette.primaryText),
          decoration: InputDecoration(
            hintText: '••••••',
            suffixIcon: onToggleVisibility == null
                ? null
                : IconButton(
                    onPressed: onToggleVisibility,
                    tooltip: obscure ? 'Show passwords' : 'Hide passwords',
                    icon: Icon(
                      obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                      color: palette.dim(0.6),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

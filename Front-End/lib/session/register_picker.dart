import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/register_identity.dart';
import 'package:pos_app/session/session_provider.dart';

/// Picks the REGISTER this terminal works — see `register_identity.dart`.
///
/// 🚨 The one screen that makes a session shared. Point two terminals at
/// "Front Till" and they sell into the same session, see the same documents and
/// payments, and either can close it.
///
/// Switching is refused while this terminal has a live session, and that is not
/// politeness: the session belongs to the register it was opened on, so moving
/// the terminal away would leave a trading till that nothing on this device can
/// reach any more — no close, no Z-report, and an expected-cash figure that
/// never gets counted.
class RegisterPickerDialog extends ConsumerStatefulWidget {
  const RegisterPickerDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const RegisterPickerDialog(),
      );

  @override
  ConsumerState<RegisterPickerDialog> createState() =>
      _RegisterPickerDialogState();
}

class _RegisterPickerDialogState extends ConsumerState<RegisterPickerDialog> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// True while this terminal is running a session — switching would strand it.
  ///
  /// 🚨 Read, not watched, but `build` watches [activeSessionProvider] so the
  /// provider is alive by the time this runs. A bare `read` on a StreamProvider
  /// nothing has subscribed to comes back loading-with-no-value, which reads as
  /// "no live session" — the guard would have waved through exactly the case it
  /// exists to stop.
  bool get _hasLiveSession {
    final s = ref.read(activeSessionProvider).value;
    return s != null && PosSessionStatus.isLive(s.status);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_hasLiveSession) {
      setState(() =>
          _error = AppLocalizations.of(context).registerSwitchBlocked);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final registers = ref.watch(companyRegistersProvider);
    final currentUid = ref.watch(registerUidProvider).value;
    final explicit = ref.watch(registerIsExplicitProvider);
    // Subscribes the provider so `_hasLiveSession` has a value to read. Its
    // result is deliberately unused here — the guard is on the ACTION, not on
    // the list, so the operator can still see which registers exist while a
    // session of their own is open.
    ref.watch(activeSessionProvider);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(l.registerChoose, style: theme.textTheme.titleMedium),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.registerSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // ── This device only ───────────────────────────────────────────
            // Always offered, always available offline: it is the device's own
            // GUID, which needs no server round trip. Everything below it does.
            _RegisterTile(
              title: l.registerThisDeviceOnly,
              subtitle: l.registerThisDeviceOnlyHint,
              icon: Icons.smartphone_outlined,
              selected: !explicit,
              onTap: _busy
                  ? null
                  : () => _run(() => RegisterIdentity.useThisDeviceOnly(ref)),
            ),
            const Divider(height: 20),

            Flexible(
              child: registers.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // A register this terminal has never worked has no local row, so
                // there is nothing honest to show offline — say so rather than
                // render an empty list that reads as "no registers exist".
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l.registerListOffline,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.warningColor),
                  ),
                ),
                data: (list) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in list)
                      _RegisterTile(
                        title: r.name.isEmpty ? r.uid : r.name,
                        subtitle: r.isLive
                            ? l.registerTrading
                            : l.registerIdle,
                        icon: Icons.point_of_sale_outlined,
                        accent: r.isLive,
                        selected: explicit && r.uid == currentUid,
                        onTap: _busy
                            ? null
                            : () => _run(() => RegisterIdentity.choose(
                                  ref,
                                  name: r.name,
                                  uid: r.uid,
                                )),
                      ),
                  ],
                ),
              ),
            ),

            const Divider(height: 20),
            Text(l.registerNew, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    maxLength: kRegisterNameMaxLength,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: l.registerNameHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() =>
                          RegisterIdentity.choose(ref, name: _name.text)),
                  child: Text(l.actionCreate),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.actionCancel),
        ),
      ],
    );
  }
}

class _RegisterTile extends StatelessWidget {
  const _RegisterTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    this.accent = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon,
          color: accent
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: selected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

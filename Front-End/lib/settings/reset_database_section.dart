import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/backup_service.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';

/// Which groups of data a reset will clear.
enum ResetEntity { products, customers, documents, everything }

/// Phases the reset moves through, in order. Shown as a live checklist so the
/// operator can see WHICH step failed if one does — a single spinner would
/// leave "did it touch the server or not?" unanswerable after a timeout.
enum _Phase { backup, server, local, done }

/// Settings → Database → **Reset database**.
///
/// ⚠️ This is the most destructive thing in the app. It deletes the selected
/// data for the whole COMPANY, on the server, so every other terminal loses it
/// on their next sync. The local `.sqlite` backup taken in step 1 protects only
/// the device that ran the reset.
///
/// Gated on `accessLevel == 0` (admin) by the caller AND re-authorised here
/// against the signed-in admin's device PIN — the same sha256→base64 check the
/// login screen performs, so it works with the API unreachable.
class ResetDatabaseSection extends ConsumerStatefulWidget {
  const ResetDatabaseSection({super.key});

  @override
  ConsumerState<ResetDatabaseSection> createState() =>
      _ResetDatabaseSectionState();
}

class _ResetDatabaseSectionState extends ConsumerState<ResetDatabaseSection> {
  final _pinCtrl = TextEditingController();
  final _selected = <ResetEntity>{};

  bool _running = false;
  bool _finished = false;
  _Phase _phase = _Phase.backup;
  String? _error;
  String? _backupPath;
  String? _summary;
  int _countdown = 5;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  /// Products and Customers both carry Documents with them: `DocumentItem` and
  /// `PosOrderItem` hold a FK to Product, and `Document`/`PosOrder` reference
  /// Customer, so the sales rows cannot outlive either. The server enforces
  /// this regardless; showing it here means the operator is never surprised by
  /// losing sales history they did not tick.
  bool get _documentsImplied =>
      _selected.contains(ResetEntity.products) ||
      _selected.contains(ResetEntity.customers) ||
      _selected.contains(ResetEntity.everything);

  bool get _canReset =>
      _selected.isNotEmpty && _pinCtrl.text.trim().isNotEmpty && !_running;

  // ── The reset itself ───────────────────────────────────────────────────────

  Future<void> _confirmAndReset() async {
    final l = AppLocalizations.of(context);
    final user = ref.read(currentUserProvider);

    // Re-authorise. Identical check to LoginScreen._verifyPin, so an admin who
    // can unlock this terminal can authorise here and nothing new is trusted.
    final attempt = base64Encode(
      sha256.convert(utf8.encode(_pinCtrl.text.trim())).bytes,
    );
    if (user?.hashedPin == null || attempt != user!.hashedPin) {
      setState(() => _error = l.resetWrongPin);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error, size: 32),
        title: Text(l.resetConfirmTitle),
        content: Text(l.resetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.resetConfirmAction),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _running = true;
      _error = null;
      _phase = _Phase.backup;
    });

    try {
      // ── 1. Backup ────────────────────────────────────────────────────────
      // Always, and a failure ABORTS: a destructive operation with no fallback
      // is not something to proceed with "best effort".
      final settings = ref.read(appSettingsProvider);
      final company = ref.read(selectedCompanyProvider);
      _backupPath = await BackupService.backupNow(
        backupDir: settings[SettingKeys.dbBackupPath] ?? '',
        companyName: company?.name ?? 'POS',
      );
      if (!mounted) return;

      // ── 2. Server ────────────────────────────────────────────────────────
      setState(() => _phase = _Phase.server);
      final companyId = company?.id;
      if (companyId == null) throw Exception(l.resetNoCompany);

      final res = await ApiClient().resetCompanyData(
        companyId,
        products: _selected.contains(ResetEntity.products),
        customers: _selected.contains(ResetEntity.customers),
        documents: _selected.contains(ResetEntity.documents),
        everything: _selected.contains(ResetEntity.everything),
      );
      _summary = res['message']?.toString();
      if (!mounted) return;

      // ── 3. This device ───────────────────────────────────────────────────
      // A FULL local wipe, not a scoped one, and only AFTER the server call
      // succeeded. Two reasons it must be total: many child tables key off a
      // parent's localId and carry no company_id at all (a scoped sweep would
      // strand them), and any surviving `pending` row would be pushed straight
      // back up, undoing the reset we just performed. The device re-pulls
      // everything clean on the next sync.
      setState(() => _phase = _Phase.local);
      await ref.read(appDatabaseProvider).purgeAllLocalData();

      // Send the terminal back to first-run, as requested.
      await ref.read(onboardingCompleteProvider.notifier).reset();

      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _finished = true;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Ticks the restart countdown one second at a time. Deliberately not a
  /// `Future.delayed(5s)`: the operator sees the number move, so a stalled
  /// restart is visibly stalled rather than looking like a frozen screen.
  Future<void> _startCountdown() async {
    while (_countdown > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _countdown--);
    }
    await _restartApp();
  }

  /// Relaunches the process, then exits this one.
  ///
  /// Desktop only, and that is a platform limit rather than a choice: Android
  /// gives an app no supported way to start itself again after `exit()`, so a
  /// tablet would simply close with no way back. There the screen keeps the
  /// "reopen the app" instruction on display instead of dying silently.
  Future<void> _restartApp() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (mounted) setState(() => _countdown = -1); // → "reopen manually"
      return;
    }
    try {
      await Process.start(
        Platform.resolvedExecutable,
        <String>[],
        workingDirectory: File(Platform.resolvedExecutable).parent.path,
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (_) {
      // Could not spawn (locked exe, permissions). Leaving the app running with
      // a wiped database is useless, so fall back to the manual instruction.
      if (mounted) setState(() => _countdown = -1);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildDone(context);
    return _buildForm(context);
  }

  Widget _buildDone(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.successColor.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.check_rounded,
                  size: 44, color: context.successColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.resetDoneTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_summary != null)
            Text(
              _summary!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          if (_backupPath != null) ...[
            const SizedBox(height: 12),
            _InfoChip(
              icon: Icons.save_outlined,
              label: l.resetBackupSavedTo(_backupPath!),
            ),
          ],
          const SizedBox(height: 24),
          if (_countdown >= 0) ...[
            SizedBox(
              width: 180,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_countdown),
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(seconds: 1),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.resetRestartingIn(_countdown),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else
            Text(
              l.resetRestartManually,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.warningColor),
            ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final backupDir = ref.watch(appSettingsProvider)[SettingKeys.dbBackupPath] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Warning banner ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.warningColor.withValues(alpha: 0.12),
              border: Border(
                left: BorderSide(color: context.warningColor, width: 3),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: context.warningColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.resetWarningBanner,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 1. Backup ──────────────────────────────────────────────────
          _Step(
            number: 1,
            title: l.resetStepBackupTitle,
            subtitle: l.resetStepBackupSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.resetStepBackupHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(backupDir),
                        initialValue: backupDir,
                        readOnly: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: BackupService.usesManagedBackupDir
                              ? l.resetBackupManagedHint
                              : l.selectBackupFolder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l.selectBackupFolder,
                      icon: const Icon(Icons.folder_open),
                      // On Android/iOS the picker hands back a SAF content://
                      // URI that no file API here can write to, so there is
                      // nothing to pick — BackupService resolves a managed
                      // folder itself.
                      onPressed: BackupService.usesManagedBackupDir || _running
                          ? null
                          : () async {
                              final picked =
                                  await FilePicker.platform.getDirectoryPath(
                                dialogTitle: l.selectBackupFolder,
                              );
                              if (picked == null || !mounted) return;
                              await ref
                                  .read(appSettingsProvider.notifier)
                                  .set(SettingKeys.dbBackupPath, picked);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 2. Entities ────────────────────────────────────────────────
          _Step(
            number: 2,
            title: l.resetStepEntitiesTitle,
            subtitle: l.resetStepEntitiesSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _entityBox(ResetEntity.products, l.products,
                    note: l.resetAlsoClearsDocuments),
                _entityBox(ResetEntity.customers, l.customersLabel,
                    note: l.resetAlsoClearsDocuments),
                _entityBox(ResetEntity.documents, l.setDocuments,
                    note: l.resetDocumentsNote,
                    // Forced on (and locked) while something implies it, so the
                    // checkbox never contradicts what will actually happen.
                    forcedOn: _documentsImplied),
                const Divider(height: 20),
                _entityBox(ResetEntity.everything, l.resetEverything,
                    note: l.resetEverythingNote, danger: true),
              ],
            ),
          ),

          // ── 3. Confirm ─────────────────────────────────────────────────
          _Step(
            number: 3,
            title: l.resetStepConfirmTitle,
            subtitle: l.resetStepConfirmSubtitle,
            isLast: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    enabled: !_running,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l.resetAdminPin,
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_running)
                  _PhaseList(phase: _phase)
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _canReset ? cs.error : null,
                      foregroundColor: _canReset ? cs.onError : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onPressed: _canReset ? _confirmAndReset : null,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l.resetDatabaseAction),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entityBox(
    ResetEntity entity,
    String label, {
    String? note,
    bool danger = false,
    bool forcedOn = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    // "Everything" subsumes the rest, so the individual boxes go inert while it
    // is ticked rather than pretending to be independent choices.
    final disabledByEverything =
        entity != ResetEntity.everything &&
        _selected.contains(ResetEntity.everything);
    final checked =
        _selected.contains(entity) || forcedOn || disabledByEverything;
    final locked = _running || forcedOn || disabledByEverything;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CheckboxListTile(
        value: checked,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: danger ? cs.error : cs.primary,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: danger ? FontWeight.w600 : FontWeight.w400,
            color: danger ? cs.error : cs.onSurface,
          ),
        ),
        subtitle: note == null
            ? null
            : Text(
                note,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
        onChanged: locked
            ? null
            : (v) => setState(() {
                  if (v == true) {
                    _selected.add(entity);
                  } else {
                    _selected.remove(entity);
                  }
                }),
      ),
    );
  }
}

/// One numbered step: the blue circle, its heading, and a hairline that runs
/// down to the next one — the layout from the reference screenshot.
class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final Widget child;
  final bool isLast;

  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: cs.outline.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                  ),
                  const Divider(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live checklist of the reset phases. Each line resolves to a tick once the
/// run has moved past it, so a failure names the step it died on.
class _PhaseList extends StatelessWidget {
  final _Phase phase;
  const _PhaseList({required this.phase});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = <_Phase, String>{
      _Phase.backup: l.resetPhaseBackup,
      _Phase.server: l.resetPhaseServer,
      _Phase.local: l.resetPhaseLocal,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in labels.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: entry.key.index < phase.index
                      ? Icon(Icons.check_circle,
                          size: 18, color: context.successColor)
                      : entry.key == phase
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                              Icons.circle_outlined,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                ),
                const SizedBox(width: 10),
                Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: entry.key == phase
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: entry.key.index <= phase.index
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/shift/shift_provider.dart';
import 'package:pos_app/time_clock/time_clock_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class TimeClockScreen extends ConsumerStatefulWidget {
  const TimeClockScreen({super.key});

  @override
  ConsumerState<TimeClockScreen> createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends ConsumerState<TimeClockScreen> {
  // 0 = Clock In  |  1 = Clock Out
  int _mode = 0;

  String _pin = '';

  bool _processing = false;
  String? _feedback;   // success / error message shown after action

  void _onDigit(String d) {
    if (_pin.length >= 4 || _processing) return;
    setState(() {
      _pin += d;
      _feedback = null;
    });
    if (_pin.length == 4) _handlePinComplete();
  }

  void _onClear() => setState(() {
        _pin = '';
        _feedback = null;
      });

  Future<void> _handlePinComplete() async {
    setState(() => _processing = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;

      final user = await findUserByPin(db, companyId, _pin);
      if (user == null) {
        setState(() {
          _feedback = 'PIN not recognised. Try again.';
          _pin = '';
          _processing = false;
        });
        return;
      }

      setState(() => _processing = false);

      // Execute immediately after identification.
      await _execute(user);
    } catch (e) {
      setState(() {
        _feedback = 'Error: $e';
        _pin = '';
        _processing = false;
      });
    }
  }

  Future<void> _execute(UsersTableData user) async {
    setState(() => _processing = true);
    // Unified pipeline: clock-in/out writes to the SAME shiftsTable as the
    // Shift Management dashboard, attributed to the PIN-identified employee.
    final notifier = ref.read(shiftNotifierProvider.notifier);

    String? error;
    if (_mode == 0) {
      if (await notifier.hasOpenShift(user.id)) {
        error = 'Already clocked in.';
      } else {
        await notifier.startShift(0, userId: user.id);
      }
    } else {
      final closed = await notifier.closeShiftForUser(user.id);
      if (!closed) error = 'Not currently clocked in.';
    }

    final displayName = [user.firstName, user.lastName]
        .where((p) => p != null && p.isNotEmpty)
        .join(' ')
        .trim()
        .isNotEmpty
        ? [user.firstName, user.lastName]
            .where((p) => p != null && p.isNotEmpty)
            .join(' ')
            .trim()
        : user.username ?? 'Employee';

    setState(() {
      _processing = false;
      _pin = '';
      if (error != null) {
        _feedback = error;
      } else {
        _feedback = _mode == 0
            ? '$displayName clocked in at ${_timeNow()}'
            : '$displayName clocked out at ${_timeNow()}';
      }
    });
  }

  String _timeNow() => DateFormat('HH:mm').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bool isFeedbackPositive =
        _feedback != null && !_feedback!.startsWith('Error') &&
        !_feedback!.contains('not') &&
        !_feedback!.contains('recognised') &&
        !_feedback!.contains('Already');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Time Clock'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Mode toggle ────────────────────────────────────────────
              _ModeToggle(
                mode: _mode,
                onChanged: (m) => setState(() {
                  _mode = m;
                  _pin = '';
                  _feedback = null;
                }),
              ),

              const SizedBox(height: 28),

              // ── PIN dots ───────────────────────────────────────────────
              Text(
                'Enter PIN',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? cs.primary : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              // ── Feedback / status ──────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _processing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _feedback != null
                        ? Container(
                            key: ValueKey(_feedback),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isFeedbackPositive
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : cs.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _feedback!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isFeedbackPositive
                                    ? Colors.green
                                    : cs.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox(height: 40),
              ),

              const SizedBox(height: 20),

              // ── Number grid ────────────────────────────────────────────
              SizedBox(
                width: 340,
                child: _NumberGrid(
                  onDigit: _onDigit,
                  onClear: _onClear,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE TOGGLE  (CLOCK IN / CLOCK OUT)
// ─────────────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final int mode;
  final ValueChanged<int> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeButton(
          label: 'CLOCK IN',
          icon: Icons.login,
          selected: mode == 0,
          selectedColor: Colors.green,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 12),
        Icon(Icons.access_time, size: 36, color: cs.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 12),
        _ModeButton(
          label: 'CLOCK OUT',
          icon: Icons.logout,
          selected: mode == 1,
          selectedColor: cs.error,
          onTap: () => onChanged(1),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? selectedColor
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? selectedColor.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? selectedColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? selectedColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUMBER GRID  (1–9, 0, Clear)
// ─────────────────────────────────────────────────────────────────────────────

class _NumberGrid extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  const _NumberGrid({required this.onDigit, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Row layout: [1][2][3] / [4][5][6] / [7][8][9] / [_][0][Clear]
    const keys = ['1','2','3','4','5','6','7','8','9','','0','Clear'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];
        if (k.isEmpty) return const SizedBox.shrink();

        if (k == 'Clear') {
          return _GridKey(
            label: k,
            textColor: cs.error,
            borderColor: cs.outlineVariant,
            onTap: onClear,
          );
        }
        return _GridKey(
          label: k,
          textColor: cs.onSurface,
          borderColor: cs.outlineVariant,
          onTap: () => onDigit(k),
        );
      },
    );
  }
}

class _GridKey extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;
  const _GridKey({
    required this.label,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: label == 'Clear' ? 15 : 22,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE STATUS WIDGET  (shown in MainLayout sidebar when user is clocked in)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// TOTAL HOURS BADGE  (shown in sidebar below the clocked-in chip)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows today's total worked hours for the current user using the
/// conditional format defined in [formatSidebarDuration]:
///   < 60 min → "-Xm"  |  ≥ 60 min → "HH:MM"
class TotalHoursBadge extends ConsumerWidget {
  const TotalHoursBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayTotalMinutesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (minutes) {
        if (minutes == 0) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final label = formatSidebarDuration(minutes);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 16, 6),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 13, color: cs.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Today: $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE STATUS WIDGET  (shown in MainLayout sidebar when user is clocked in)
// ─────────────────────────────────────────────────────────────────────────────

/// Live sidebar indicator: shows "Clocked in · HH:MM" with a flat status dot
/// while the current user has an open shift. Watches [activeShiftProvider] (the
/// unified shiftsTable source) and re-ticks once a minute so the elapsed time
/// advances on-screen instead of sitting flat at 0m.
class TimeClockStatusChip extends ConsumerStatefulWidget {
  const TimeClockStatusChip({super.key});

  @override
  ConsumerState<TimeClockStatusChip> createState() =>
      _TimeClockStatusChipState();
}

class _TimeClockStatusChipState extends ConsumerState<TimeClockStatusChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Low-overhead: a single empty setState per minute re-evaluates the
    // elapsed duration. Cancelled in dispose — zero background leakage.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shiftAsync = ref.watch(activeShiftProvider);

    return shiftAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (shift) {
        if (shift == null) return const SizedBox.shrink();

        final raw = DateTime.now().difference(shift.openedAt).inMinutes;
        final minutes = raw < 0 ? 0 : raw;
        final label = formatSidebarDuration(minutes);
        // < 1h → warning highlight (error); ≥ 1h → standard accent.
        final color = minutes < 60 ? cs.error : context.navAccent;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clocked in · $label',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

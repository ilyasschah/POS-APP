import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class VoidReasonModel {
  final int id;
  final String name;
  final int rank;

  const VoidReasonModel({required this.id, required this.name, required this.rank});

  factory VoidReasonModel.fromJson(Map<String, dynamic> j) => VoidReasonModel(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        rank: j['rank'] ?? 0,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Offline-first: streams void reasons from the local Drift cache. Seeded by
/// SyncManager.pullVoidReasons; admin edits trigger a sync to refresh it.
final voidReasonsProvider =
    StreamProvider.autoDispose<List<VoidReasonModel>>((ref) {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const <VoidReasonModel>[]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchVoidReasons(companyId).map((rows) => rows
      .map((r) => VoidReasonModel(id: r.id, name: r.name, rank: r.rank))
      .toList());
});

// ── Screen ────────────────────────────────────────────────────────────────────

class VoidReasonsScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const VoidReasonsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<VoidReasonsScreen> createState() => _VoidReasonsScreenState();
}

class _VoidReasonsScreenState extends ConsumerState<VoidReasonsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Ticked rows, by reason id.
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      // Selection is by id and survives filtering, so a row the search hid must
      // drop out of it.
      _selectedIds.clear();
    });
  }

  List<VoidReasonModel> _visible(List<VoidReasonModel> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _openEditor([VoidReasonModel? reason]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _VoidReasonEditorDialog(reason: reason),
    );
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final l = AppLocalizations.of(context);
    final targets = Set<int>.from(_selectedIds);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteVoidReason),
        content: Text(targets.length == 1
            ? l.deleteVoidReasonConfirm
            : l.deleteProductsConfirm(targets.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // Offline-first: tombstone locally (the list drops it instantly via the
      // Drift stream); SyncManager issues /VoidReasons/Delete on the next push.
      for (final id in targets) {
        await ref.read(appDatabaseProvider).deleteVoidReasonLocal(id);
      }
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (mounted) setState(_selectedIds.clear);
    } catch (_) {
      if (mounted) {
        showAppSnackbar(context, ref, AppLocalizations.of(context).deleteFailed,
            isError: true);
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reasons = ref.watch(voidReasonsProvider);
    final hasSelection = _selectedIds.isNotEmpty;

    return IlyassListScaffold(
      title: l.voidReasons,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _searchCtrl,
        singleLine: true,
        hintText: l.actionSearch,
        chips: const [],
        sectionsBuilder: (_) => const [],
        onQueryChanged: _setQuery,
        onClearAll: () {
          _searchCtrl.clear();
          _setQuery('');
        },
      ),
      actions: [
        IlyassMenuAction(
          icon: Icons.delete_outline_rounded,
          label: hasSelection
              ? l.deleteWithCount(_selectedIds.length)
              : l.actionDelete,
          color: hasSelection ? context.dangerColor : null,
          enabled: hasSelection,
          onSelected: _bulkDelete,
        ),
      ],
      fabLabel: l.addReason,
      onFabPressed: _openEditor,
      body: reasons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(l.errorWithMessage(e.toString()),
                style: TextStyle(color: theme.colorScheme.error))),
        data: (all) {
          final list = _visible(all);
          final selected =
              _selectedIds.intersection(list.map((r) => r.id).toSet());

          return IlyassTable<VoidReasonModel>(
            tableId: 'voidReasons',
            rows: list,
            rowHeight: 64,
            onRowTap: _openEditor,
            isRowSelected: (r) => selected.contains(r.id),
            columns: [
              ilyassSelectionColumn<VoidReasonModel, int>(
                rows: list,
                selected: selected,
                idOf: (r) => r.id,
                onChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              IlyassColumn<VoidReasonModel>(
                key: 'name',
                label: l.fieldName,
                width: 280,
                flexible: true,
                cell: (context, r) => Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IlyassColumn<VoidReasonModel>(
                key: 'rank',
                label: l.fieldRank,
                width: 120,
                numeric: true,
                cell: (context, r) => Text('${r.rank}'),
              ),
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_outlined,
                        size: 64,
                        color: theme.disabledColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      all.isEmpty ? l.noVoidReasonsYet : l.noResultsForFilters,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Add / edit one void reason.
///
/// Was a permanent 320px form pinned to the right of the list, which cost that
/// width on every screen whether or not anything was being edited. A dialog
/// costs nothing until it is opened.
class _VoidReasonEditorDialog extends ConsumerStatefulWidget {
  const _VoidReasonEditorDialog({this.reason});

  final VoidReasonModel? reason;

  @override
  ConsumerState<_VoidReasonEditorDialog> createState() =>
      _VoidReasonEditorDialogState();
}

class _VoidReasonEditorDialogState
    extends ConsumerState<_VoidReasonEditorDialog> {
  late final _nameCtrl = TextEditingController(text: widget.reason?.name ?? '');
  late final _rankCtrl =
      TextEditingController(text: '${widget.reason?.rank ?? 0}');

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.reason != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rankCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final rank = int.tryParse(_rankCtrl.text.trim()) ?? 0;
    final l10n = AppLocalizations.of(context);

    if (name.isEmpty) {
      setState(() => _error = l10n.nameIsRequired);
      return;
    }
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) {
      setState(() => _error = l10n.noCompanySelectedShort);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Offline-first: write to the local DB first so the list updates instantly
      // via the Drift stream; SyncManager pushes /VoidReasons/Add|Update later.
      await ref.read(appDatabaseProvider).saveVoidReasonLocal(
            id: widget.reason?.id,
            companyId: companyId,
            name: name,
            rank: rank,
          );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.saveFailedShort);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_isEditing ? l.editVoidReason : l.addVoidReason),
      content: SizedBox(
        width: context.dialogWidth(380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l.nameRequired,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rankCtrl,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l.rankDisplayOrderLower,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.sort),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l.actionCancel),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_isEditing ? Icons.save : Icons.add),
          label: Text(_isEditing ? l.actionSaveChanges : l.addReason),
        ),
      ],
    );
  }
}

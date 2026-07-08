import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
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
  final _nameCtrl = TextEditingController();
  final _rankCtrl = TextEditingController(text: '0');
  int? _selectedId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rankCtrl.dispose();
    super.dispose();
  }

  void _selectReason(VoidReasonModel r) {
    setState(() {
      _selectedId = r.id;
      _nameCtrl.text = r.name;
      _rankCtrl.text = r.rank.toString();
      _error = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedId = null;
      _nameCtrl.clear();
      _rankCtrl.text = '0';
      _error = null;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final rank = int.tryParse(_rankCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) {
      setState(() => _error = 'No company selected.');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      // Offline-first: write to the local DB first so the list updates instantly
      // via the Drift stream; SyncManager pushes /VoidReasons/Add|Update later.
      await ref.read(appDatabaseProvider).saveVoidReasonLocal(
            id: _selectedId,
            companyId: companyId,
            name: name,
            rank: rank,
          );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      _clearSelection();
    } catch (e) {
      setState(() => _error = 'Save failed.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Void Reason'),
        content: const Text('Are you sure you want to delete this void reason?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Offline-first: tombstone locally (list drops it instantly via the Drift
      // stream); SyncManager issues /VoidReasons/Delete on the next push.
      await ref.read(appDatabaseProvider).deleteVoidReasonLocal(id);
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (_selectedId == id) _clearSelection();
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Delete failed.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reasons = ref.watch(voidReasonsProvider);
    final isEditing = _selectedId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Void Reasons', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Show navigation',
                onPressed: widget.onMenuPressed,
              )
            : null,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: list ───────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: reasons.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text('No void reasons yet.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final selected = r.id == _selectedId;
                    return Card(
                      elevation: 0,
                      color: selected ? cs.primaryContainer : cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: selected ? cs.primary : cs.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.secondaryContainer,
                          child: Text('${r.rank}',
                              style: TextStyle(
                                  color: cs.onSecondaryContainer,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(r.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected ? cs.onPrimaryContainer : cs.onSurface,
                            )),
                        onTap: () => _selectReason(r),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          tooltip: 'Delete',
                          onPressed: () => _delete(r.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Right: form ──────────────────────────────────────────────
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: cs.outlineVariant)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Edit Void Reason' : 'Add Void Reason',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rankCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rank (display order)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sort),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(isEditing ? 'Save Changes' : 'Add Reason'),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel Edit'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

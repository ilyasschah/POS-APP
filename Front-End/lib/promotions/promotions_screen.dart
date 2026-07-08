import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/promotions/promotion_edit_dialog.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(allPromotionsProvider);
    final cs = Theme.of(context).colorScheme;

    // Helper so the three callbacks below stay readable.
    Future<void> refreshFromServer() async {
      final companyId = ref.read(selectedCompanyProvider)?.id;
      if (companyId == null) return;
      await ref.read(syncManagerProvider).pullPromotions(companyId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const PromotionEditDialog(),
              ).then((_) => refreshFromServer());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshFromServer,
          ),
        ],
      ),
      body: promotionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (promotions) {
          if (promotions.isEmpty) {
            return const Center(child: Text('No promotions found.'));
          }
          return ListView.builder(
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promotion = promotions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(promotion.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${promotion.isEnabled ? "Active" : "Inactive"} | Items: ${promotion.items.length}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: cs.primary),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                PromotionEditDialog(promotion: promotion),
                          ).then((_) => refreshFromServer());
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: cs.error),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content:
                                          Text('Delete ${promotion.name}?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel')),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: cs.error,
                                                foregroundColor: cs.onError),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Delete')),
                                      ]));
                          if (confirm == true) {
                            final companyId =
                                ref.read(selectedCompanyProvider)?.id;
                            if (companyId != null) {
                              try {
                                await ApiClient()
                                    .deletePromotion(companyId, promotion.id);
                                // Pull the delta back into Drift so the
                                // StreamProvider re-emits and the deleted
                                // row disappears from the list.
                                await ref
                                    .read(syncManagerProvider)
                                    .pullPromotions(companyId);
                              } catch (e) {
                                if (context.mounted) {
                                  showAppSnackbar(context, ref, 'Error: $e', isError: true);
                                }
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

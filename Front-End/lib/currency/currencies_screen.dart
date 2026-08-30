import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/currency/currency_model.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// --- PROVIDER (No CompanyId Required!) ---
final allCurrenciesProvider =
    FutureProvider.autoDispose<List<Currency>>((ref) async {
  final dio = createDio();
  final response = await dio.get('/Currencies/GetAll');
  return (response.data as List).map((j) => Currency.fromJson(j)).toList();
});

// --- HELPER: CLEAN ERROR PARSER ---
String _parseApiError(dynamic e) {
  if (e is DioException && e.response?.data != null) {
    final data = e.response!.data;
    if (data is Map && data.containsKey('message')) {
      return data['message'].toString();
    }
    if (data is String && !data.contains('<html') && data.length < 150) {
      return data;
    }
  }
  return "A server error occurred. Please check your inputs.";
}

// --- MAIN SCREEN ---
class CurrenciesScreen extends ConsumerWidget {
  const CurrenciesScreen({super.key});

  Future<void> _deleteCurrency(
      BuildContext context, WidgetRef ref, Currency currency) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteCurrency),
        content: Text(AppLocalizations.of(context).confirmDeleteQuoted(currency.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).actionCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ctx.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).actionDelete, style: TextStyle(color: ctx.onStatusColor)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      final dio = createDio();
      // No companyId required for delete!
      await dio
          .delete('/Currencies/Delete', queryParameters: {'id': currency.id});
      ref.invalidate(allCurrenciesProvider);
      if (context.mounted) {
        showAppSnackbar(
            context, ref, AppLocalizations.of(context).currencyDeleted);
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackbar(context, ref, _parseApiError(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCurrencies = ref.watch(allCurrenciesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).globalCurrencies),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.payments),
        label: Text(AppLocalizations.of(context).newCurrency),
        onPressed: () => showDialog(
                context: context, builder: (_) => const _CurrencyEditorDialog())
            .then((_) => ref.invalidate(allCurrenciesProvider)),
      ),
      body: asyncCurrencies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(AppLocalizations.of(context).errorWithMessage(_parseApiError(e)),
                style: TextStyle(color: context.dangerColor))),
        data: (currencies) {
          if (currencies.isEmpty) {
            return Center(
                child: Text(AppLocalizations.of(context).noCurrenciesFound,
                    style: const TextStyle(color: Colors.grey, fontSize: 16)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: currencies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final currency = currencies[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(currency.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(AppLocalizations.of(context).codeValueLabel(currency.code ?? 'N/A'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) =>
                              _CurrencyEditorDialog(existingCurrency: currency),
                        ).then((_) => ref.invalidate(allCurrenciesProvider)),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: context.dangerColor),
                        onPressed: () =>
                            _deleteCurrency(context, ref, currency),
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

// --- ADD/EDIT DIALOG ---
class _CurrencyEditorDialog extends StatefulWidget {
  final Currency? existingCurrency;
  const _CurrencyEditorDialog({this.existingCurrency});

  @override
  State<_CurrencyEditorDialog> createState() => _CurrencyEditorDialogState();
}

class _CurrencyEditorDialogState extends State<_CurrencyEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingCurrency != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.existingCurrency!.name;
      _codeCtrl.text = widget.existingCurrency!.code ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = createDio();

      if (_isEditing) {
        final payload = {
          'name': _nameCtrl.text.trim(),
          'code': _codeCtrl.text.trim().toUpperCase(),
        };
        await dio.patch('/Currencies/Update',
            queryParameters: {'id': widget.existingCurrency!.id},
            data: payload);
      } else {
        final payload = {
          'name': _nameCtrl.text.trim(),
          'code': _codeCtrl.text.trim().toUpperCase(),
          'countryId':
              1, // Fallback required by your C# CreateCurrencyRequest model
        };
        await dio.post('/Currencies/Add', data: payload);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = _parseApiError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
          _isEditing
              ? AppLocalizations.of(context).editCurrency
              : AppLocalizations.of(context).newCurrency,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 350,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).currencyNameRequired,
                    border: const OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeCtrl,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).currencyCodeRequired,
                    border: const OutlineInputBorder()),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: context.dangerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: context.dangerColor.withValues(alpha: 0.4))),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: context.dangerColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_errorMessage!,
                              style: TextStyle(
                                  color: context.dangerColor, fontSize: 13))),
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).actionCancel)),
        if (_isLoading)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)))
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: _submit,
            child: Text(_isEditing
              ? AppLocalizations.of(context).actionUpdate
              : AppLocalizations.of(context).actionCreate),
          ),
      ],
    );
  }
}

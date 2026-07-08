// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/user_model.dart';

class CompanySelectionScreen extends ConsumerWidget {
  const CompanySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(allCompaniesProvider);

    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Your Company",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              companiesAsync.when(
                data: (list) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(list[i].name),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      final company = list[i];
                      ref.read(selectedCompanyProvider.notifier).state =
                          company;
                      ref
                          .read(defaultCompanyIdProvider.notifier)
                          .setDefaultCompany(company.id);
                      final dio = createDio();
                      List<User> users = [];
                      try {
                        final response = await dio.get(
                          '/Users/GetAllUsers',
                          queryParameters: {'companyId': company.id},
                        );
                        users = (response.data as List)
                            .map((j) => User.fromJson(j))
                            .where((u) => u.isEnabled)
                            .toList();
                      } catch (_) {
                        users = [];
                      }

                      if (!context.mounted) return;

                      if (users.isEmpty) {
                        // Block login — show Create First User dialog
                        await showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => _CreateFirstUserDialog(
                            companyId: company.id,
                            companyName: company.name,
                          ),
                        );
                        // After dialog, re-check then navigate
                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      } else {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text("Error: $e"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CREATE FIRST USER DIALOG ---
class _CreateFirstUserDialog extends ConsumerStatefulWidget {
  final int companyId;
  final String companyName;

  const _CreateFirstUserDialog({
    required this.companyId,
    required this.companyName,
  });

  @override
  ConsumerState<_CreateFirstUserDialog> createState() =>
      _CreateFirstUserDialogState();
}

class _CreateFirstUserDialogState
    extends ConsumerState<_CreateFirstUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  int _accessLevel = 0; // default: Admin
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
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
      await dio.post(
        '/Users/Add',
        queryParameters: {'companyId': widget.companyId},
        data: {
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'accessLevel': _accessLevel,
          'isEnabled': true,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close dialog, proceed to login
    } on DioException catch (e) {
      setState(() {
        _errorMessage =
            e.response?.data?.toString() ?? "Failed to create user.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("No Users Found",
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            "Create the first admin user for ${widget.companyName}",
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration:
                          const InputDecoration(labelText: "First Name"),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(labelText: "Last Name"),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: "Username"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _accessLevel,
                decoration: const InputDecoration(labelText: "Access Level"),
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Admin")),
                  DropdownMenuItem(value: 1, child: Text("Cashier")),
                ],
                onChanged: (v) => setState(() => _accessLevel = v ?? 0),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text("Create User"),
            onPressed: _submit,
          ),
      ],
    );
  }
}

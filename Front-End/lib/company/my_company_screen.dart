import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/country_model.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class MyCompanyScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const MyCompanyScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<MyCompanyScreen> createState() => _MyCompanyScreenState();
}

class _MyCompanyScreenState extends ConsumerState<MyCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoadingCompany = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  String? _loadError;
  String? _errorMessage;
  Uint8List? _selectedLogoBytes;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _streetNameCtrl = TextEditingController();
  final _buildingNumberCtrl = TextEditingController();
  final _additionalStreetCtrl = TextEditingController();
  final _plotIdCtrl = TextEditingController();
  final _citySubdivisionCtrl = TextEditingController();
  final _countrySubentityCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankDetailsCtrl = TextEditingController();

  // Country dropdown state
  List<Country> _countries = [];
  int? _selectedCountryId;
  bool _countriesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyAndCountries();
  }

  Future<void> _loadCompanyAndCountries() async {
    final selected = ref.read(selectedCompanyProvider);
    if (selected == null) {
      setState(() => _isLoadingCompany = false);
      return;
    }

    setState(() {
      _isLoadingCompany = true;
      _loadError = null;
    });

    try {
      // Offline-first: read the full company + country list from the local
      // Drift cache (populated by pullCompany / pullCountries). No network.
      final db = ref.read(appDatabaseProvider);

      final row = await (db.select(db.companiesTable)
            ..where((t) => t.id.equals(selected.id)))
          .getSingleOrNull();
      final company = row != null ? Company.fromDrift(row) : selected;

      _nameCtrl.text = company.name;
      _taxNumberCtrl.text = company.taxNumber ?? '';
      _streetNameCtrl.text = company.streetName ?? '';
      _buildingNumberCtrl.text = company.buildingNumber ?? '';
      _additionalStreetCtrl.text = company.additionalStreetName ?? '';
      _plotIdCtrl.text = company.plotIdentification ?? '';
      _citySubdivisionCtrl.text = company.citySubdivisionName ?? '';
      _countrySubentityCtrl.text = company.countrySubentity ?? '';
      _postalCodeCtrl.text = company.postalCode ?? '';
      _cityCtrl.text = company.city ?? '';
      _emailCtrl.text = company.email ?? '';
      _phoneCtrl.text = company.phoneNumber ?? '';
      _bankAccountCtrl.text = company.bankAccountNumber ?? '';
      _bankDetailsCtrl.text = company.bankDetails ?? '';

      // Country dropdown from the cached countries table. serverId is the real
      // id that company.countryId references.
      final countryRows = await db.select(db.countriesTable).get();
      final countries = countryRows
          .map((r) => Country(
                id: r.serverId ?? r.id,
                name: r.name,
                code: r.code,
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _countries = countries;
        final hasMatch = company.countryId != null &&
            company.countryId! > 0 &&
            countries.any((c) => c.id == company.countryId);
        _selectedCountryId = hasMatch
            ? company.countryId
            : (countries.isNotEmpty ? countries.first.id : null);
        _countriesLoading = false;
        _isLoadingCompany = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'An unexpected error occurred. Please try again.';
        _isLoadingCompany = false;
        _countriesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxNumberCtrl.dispose();
    _streetNameCtrl.dispose();
    _buildingNumberCtrl.dispose();
    _additionalStreetCtrl.dispose();
    _plotIdCtrl.dispose();
    _citySubdivisionCtrl.dispose();
    _countrySubentityCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankDetailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null || _isUploadingLogo) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedLogoBytes = bytes;
      _isUploadingLogo = true;
    });

    try {
      final base64Logo = base64Encode(bytes);
      final dio = createDio();
      await dio.put(
        '/Company/UpdateLogo',
        data: {'id': company.id, 'logo': base64Logo},
      );

      ref.read(selectedCompanyProvider.notifier).updateLogo(base64Logo);
      ref.invalidate(allCompaniesProvider);

      if (mounted) showAppSnackbar(context, ref, 'Logo updated successfully');
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _selectedLogoBytes = null);
        showAppSnackbar(
          context, ref,
          e.response?.data?.toString() ?? 'Failed to upload logo.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    if (_selectedCountryId == null) {
      setState(() => _errorMessage = "Please select a country.");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Offline-first: write the edit to the local cache (pending_update) so it
      // shows instantly; SyncManager pushes /Company/Update on the next sync.
      await ref.read(appDatabaseProvider).saveCompanyLocal(
            id: company.id,
            name: _nameCtrl.text.trim(),
            countryId: _selectedCountryId,
            taxNumber: _taxNumberCtrl.text.trim(),
            streetName: _streetNameCtrl.text.trim(),
            buildingNumber: _buildingNumberCtrl.text.trim(),
            additionalStreetName: _additionalStreetCtrl.text.trim(),
            plotIdentification: _plotIdCtrl.text.trim(),
            citySubdivisionName: _citySubdivisionCtrl.text.trim(),
            countrySubentity: _countrySubentityCtrl.text.trim(),
            postalCode: _postalCodeCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            bankAccountNumber: _bankAccountCtrl.text.trim(),
            bankDetails: _bankDetailsCtrl.text.trim(),
          );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});

      if (!mounted) return;
      showAppSnackbar(context, ref, 'Company updated successfully');

      final countryName = _countries
          .where((c) => c.id == _selectedCountryId)
          .map((c) => c.name)
          .firstOrNull ?? company.countryName;
      final updatedCompany = Company(
        id: company.id,
        name: _nameCtrl.text.trim(),
        countryId: _selectedCountryId,
        countryName: countryName,
        taxNumber: _taxNumberCtrl.text.trim(),
        streetName: _streetNameCtrl.text.trim(),
        buildingNumber: _buildingNumberCtrl.text.trim(),
        additionalStreetName: _additionalStreetCtrl.text.trim(),
        plotIdentification: _plotIdCtrl.text.trim(),
        citySubdivisionName: _citySubdivisionCtrl.text.trim(),
        countrySubentity: _countrySubentityCtrl.text.trim(),
        postalCode: _postalCodeCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        bankAccountNumber: _bankAccountCtrl.text.trim(),
        bankDetails: _bankDetailsCtrl.text.trim(),
        logo: company.logo,
      );
      ref.read(selectedCompanyProvider.notifier).update(updatedCompany);
      ref.invalidate(allCompaniesProvider);
    } catch (e) {
      setState(() => _errorMessage = "Failed to save changes.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(selectedCompanyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(company?.name ?? "My Company"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: AppLocalizations.of(context).showNavigation,
                onPressed: widget.onMenuPressed,
              )
            : null,
      ),
      body: _isLoadingCompany
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : _loadError != null
          ? _buildLoadError()
          : company == null
          ? Center(
              child: Text(
                AppLocalizations.of(context).noCompanySelectedShort,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1000,
                ), // WIDENED MAX WIDTH
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildLogoSection(company, theme),
                        const SizedBox(height: 32),

                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.error,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // --- MODULAR CARDS FOR WIDER LAYOUT ---
                        _buildSectionCard(
                          context: context,
                          title: AppLocalizations.of(context).generalInfo,
                          icon: Icons.business,
                          children: [
                            _buildRow([
                              _field(
                                context,
                                _nameCtrl,
                                AppLocalizations.of(context).companyName,
                                icon: Icons.storefront,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? "Required"
                                    : null,
                              ),
                              _field(
                                context,
                                _taxNumberCtrl,
                                AppLocalizations.of(context).taxNumberLabel,
                                icon: Icons.receipt_long,
                              ),
                            ]),
                            _buildRow([
                              _field(
                                context,
                                _emailCtrl,
                                AppLocalizations.of(context).emailAddress,
                                icon: Icons.email_outlined,
                              ),
                              _field(
                                context,
                                _phoneCtrl,
                                AppLocalizations.of(context).phoneNumber,
                                icon: Icons.phone_outlined,
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _buildSectionCard(
                          context: context,
                          title: AppLocalizations.of(context).locationAddress,
                          icon: Icons.location_on_outlined,
                          children: [
                            _buildRow([
                              _field(
                                context,
                                _streetNameCtrl,
                                AppLocalizations.of(context).streetName,
                                icon: Icons.add_road,
                              ),
                              _field(
                                context,
                                _buildingNumberCtrl,
                                AppLocalizations.of(context).buildingNo,
                                icon: Icons.numbers,
                              ),
                              _field(
                                context,
                                _additionalStreetCtrl,
                                AppLocalizations.of(context).additionalStreet,
                                icon: Icons.edit_road,
                              ),
                            ]),
                            _buildRow([
                              _field(
                                context,
                                _plotIdCtrl,
                                AppLocalizations.of(context).plotId,
                                icon: Icons.map_outlined,
                              ),
                              _field(
                                context,
                                _citySubdivisionCtrl,
                                AppLocalizations.of(context).districtSubdivision,
                                icon: Icons.holiday_village_outlined,
                              ),
                              _field(
                                context,
                                _postalCodeCtrl,
                                AppLocalizations.of(context).postalCode,
                                icon: Icons.local_post_office_outlined,
                              ),
                            ]),
                            _buildRow([
                              _field(
                                context,
                                _cityCtrl,
                                AppLocalizations.of(context).cityLabel,
                                icon: Icons.location_city_outlined,
                              ),
                              _field(
                                context,
                                _countrySubentityCtrl,
                                AppLocalizations.of(context).stateProvince,
                                icon: Icons.public_outlined,
                              ),
                              _buildCountryDropdown(theme),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _buildSectionCard(
                          context: context,
                          title: AppLocalizations.of(context).financialInfo,
                          icon: Icons.account_balance_outlined,
                          children: [
                            _buildRow([
                              _field(
                                context,
                                _bankAccountCtrl,
                                AppLocalizations.of(context).bankAccountNumber,
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                            ]),
                            _buildRow([
                              _field(
                                context,
                                _bankDetailsCtrl,
                                AppLocalizations.of(context).bankDetails,
                                icon: Icons.description_outlined,
                                maxLines: 3,
                              ),
                            ]),
                          ],
                        ),

                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _isSaving ? "SAVING..." : "SAVE COMPANY CHANGES",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Modular UI Builders ──────────────────────────────────────────────────

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.asMap().entries.map((entry) {
          final int idx = entry.key;
          final Widget w = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: idx == children.length - 1 ? 0 : 16.0,
              ),
              child: w,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _fieldWrapper(
    BuildContext context,
    String label,
    Widget child, {
    bool isRequired = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? "$label *" : label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(
    ThemeData theme, {
    IconData? icon,
    String? hintText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: theme.colorScheme.primary, size: 20)
          : null,
      hintText: hintText,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String label, {
    IconData? icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return _fieldWrapper(
      context,
      label,
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        decoration: _inputDecoration(
          theme,
          icon: icon,
          hintText: AppLocalizations.of(context).enterFieldHint(label),
        ),
        validator: validator,
      ),
      isRequired: validator != null,
    );
  }

  Widget _buildCountryDropdown(ThemeData theme) {
    return _fieldWrapper(
      context,
      AppLocalizations.of(context).country,
      _countriesLoading
          ? const SizedBox(
              height: 54,
              child: Center(child: LinearProgressIndicator()),
            )
          : DropdownButtonFormField<int>(
              initialValue: _selectedCountryId,
              dropdownColor: theme.colorScheme.surfaceContainerHighest,
              decoration: _inputDecoration(theme, icon: Icons.public),
              items: _countries
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.name,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCountryId = v),
              validator: (v) => v == null ? "Required" : null,
            ),
      isRequired: true,
    );
  }

  // ── Extracted Loading & Logo Widgets ─────────────────────────────────────

  Widget _buildLoadError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCompanyAndCountries,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context).actionRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection(company, ThemeData theme) {
    ImageProvider? imageProvider;
    if (_selectedLogoBytes != null) {
      imageProvider = MemoryImage(_selectedLogoBytes!);
    } else if (company.logo != null && (company.logo as String).isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(company.logo as String));
      } catch (_) {}
    }

    final hasLogo = imageProvider != null;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (hasLogo)
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: hasLogo
                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                      : theme.colorScheme.outline.withValues(alpha: 0.25),
                  width: hasLogo ? 2.5 : 1.5,
                ),
                boxShadow: hasLogo
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipOval(
                child: hasLogo
                    ? Image(image: imageProvider, fit: BoxFit.cover)
                    : _LogoPlaceholder(theme: theme),
              ),
            ),
            if (_isUploadingLogo)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface.withValues(alpha: 0.75),
                ),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            if (!_isUploadingLogo)
              Positioned(
                bottom: 2,
                right: 2,
                child: _CameraButton(theme: theme, onTap: _pickAndUploadLogo),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          hasLogo
              ? 'Tap the camera icon to change logo'
              : 'No logo uploaded yet',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _LogoPlaceholder extends StatelessWidget {
  final ThemeData theme;
  const _LogoPlaceholder({required this.theme});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(
        color: theme.colorScheme.outline.withValues(alpha: 0.3),
      ),
      child: Center(
        child: Icon(
          Icons.store_mall_directory_rounded,
          size: 44,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 2;
    const dashCount = 24;
    const gapFraction = 0.4;
    const totalAngle = 2 * 3.141592653589793;
    const dashAngle = (totalAngle / dashCount) * (1 - gapFraction);
    const gapAngle = (totalAngle / dashCount) * gapFraction;

    double startAngle = 0;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
      startAngle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

class _CameraButton extends StatefulWidget {
  final ThemeData theme;
  final VoidCallback onTap;
  const _CameraButton({required this.theme, required this.onTap});

  @override
  State<_CameraButton> createState() => _CameraButtonState();
}

class _CameraButtonState extends State<_CameraButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _hovered ? 40 : 36,
          height: _hovered ? 40 : 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered
                ? widget.theme.colorScheme.primary
                : widget.theme.colorScheme.primary.withValues(alpha: 0.9),
            border: Border.all(
              color: widget.theme.colorScheme.surface,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: _hovered ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.camera_alt_rounded,
            size: _hovered ? 20 : 17,
            color: widget.theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

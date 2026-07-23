import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/users_screen.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/payment_types_screen.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/company/my_company_screen.dart';
import 'package:pos_app/currency/currencies_screen.dart';
import 'package:pos_app/customer/customers_screen.dart';
import 'package:pos_app/document/documents_screen.dart';
import 'package:pos_app/menu/open_orders_screen.dart';
import 'package:pos_app/product/product_groups_screen.dart';
import 'package:pos_app/product/products_screen.dart';
import 'package:pos_app/promotions/promotions_list_screen.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/dashboard/dashboard_screen.dart';
import 'package:pos_app/reports/reports_screen.dart';
import 'package:pos_app/reports/z_report_screen.dart';
import 'package:pos_app/settings/settings_screen.dart';
import 'package:pos_app/stock/stock_screen.dart';
import 'package:pos_app/stock/warehouses_screen.dart';
import 'package:pos_app/tax/tax_rates_screen.dart';

class SharedDrawer extends ConsumerWidget {
  const SharedDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blueGrey),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.point_of_sale, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                Text(
                  selectedCompany?.name ?? 'POS System',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentUser?.displayName ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded),
            title: Text(AppLocalizations.of(context).dashboard),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(AppLocalizations.of(context).myCompany),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyCompanyScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(AppLocalizations.of(context).documents),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DocumentsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(AppLocalizations.of(context).customersLabel),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CustomersScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: Text(AppLocalizations.of(context).paymentTypesShort),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PaymentTypesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: Text(AppLocalizations.of(context).stock),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StockScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text(AppLocalizations.of(context).currencies),
            onTap: () => ref.read(securityGuardProvider).guard(
              context,
              SecurityKeys.currencies,
              () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CurrenciesScreen()));
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.percent),
            title: Text(AppLocalizations.of(context).taxRates),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TaxRatesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.warehouse),
            title: Text(AppLocalizations.of(context).warehouses),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WarehousesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.fastfood),
            title: Text(AppLocalizations.of(context).products),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProductsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_special),
            title: Text(AppLocalizations.of(context).productGroups),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ProductGroupsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_offer),
            title: Text(AppLocalizations.of(context).promotions),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PromotionsListScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: Text(AppLocalizations.of(context).users),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UsersScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(AppLocalizations.of(context).reports),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_clock),
            title: Text(AppLocalizations.of(context).endOfDay),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EndOfDayScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.pending_actions),
            title: Text(AppLocalizations.of(context).openOrders),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OpenOrdersScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(AppLocalizations.of(context).settings),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: context.dangerColor),
            title: Text(AppLocalizations.of(context).logout, style: TextStyle(color: context.dangerColor)),
            onTap: () {
              ref.invalidate(currentUserProvider);
              ref.read(cartProvider.notifier).clearCart();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

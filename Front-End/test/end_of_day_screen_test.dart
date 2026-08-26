// End of Day after the history became the screen.
//
// The rule worth a test is the FAB's existence: Close Register writes a
// Z-report over the payments nobody has reported yet, so with none of those
// the button must not be there at all. It used to be a permanent app-bar
// button whose only answer on an empty till was a "nothing to report" toast.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/cart/payment_model.dart';
import 'package:pos_app/cart/payment_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:pos_app/reports/z_report_provider.dart';
import 'package:pos_app/reports/z_report_screen.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ZReportModel report(int number, DateTime date, {double total = 100}) =>
    ZReportModel(
      id: number,
      companyId: 1,
      number: number,
      dateCreated: date,
      fromDocumentId: 0,
      toDocumentId: 0,
      documentCount: 4,
      fromDocumentNumber: '26-200-00000$number',
      toDocumentNumber: '26-200-00001$number',
      totalSales: total,
      totalReturns: 0,
      discountsGranted: 0,
      taxableTotal: total,
      totalTax: 0,
      grandTotal: total,
      paymentSummaries: const [],
    );

PaymentModel payment(double amount) => PaymentModel(
      id: 1,
      documentId: 1,
      paymentTypeId: 1,
      paymentTypeName: 'Cash',
      amount: amount,
      date: DateTime(2026, 8, 26),
      userId: 1,
    );

void main() {
  final today = DateTime.now();
  final lastYear = DateTime(today.year - 1, 5, 12);

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ZReportModel>? reports,
    List<PaymentModel> unreported = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencySymbolProvider.overrideWithValue('MAD'),
        allZReportsProvider.overrideWith((ref) async =>
            reports ?? [report(2, today), report(1, lastYear)]),
        unreportedPaymentsProvider.overrideWith((ref) async => unreported),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EndOfDayScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty till offers no Close Register button', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(FloatingActionButton), findsNothing);
    // The history is still the screen.
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('unreported payments raise a red Close Register FAB',
      (tester) async {
    await pumpScreen(tester, unreported: [payment(240)]);

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    final context = tester.element(fab);
    expect(
      tester.widget<FloatingActionButton>(fab).backgroundColor,
      Theme.of(context).colorScheme.error,
      reason: 'closing the day is destructive and reads as destructive',
    );
    expect(find.text(AppLocalizations.of(context).closeRegister),
        findsOneWidget);
  });

  testWidgets('the FAB confirms with the tender breakdown before closing',
      (tester) async {
    await pumpScreen(tester, unreported: [payment(240)]);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
    // The old "Current Shift" tab's numbers, now where the decision is made.
    expect(find.text(l.tenderBreakdown), findsOneWidget);
    expect(find.text(l.expectedInDrawer), findsOneWidget);
    expect(find.text('240.00 MAD'), findsWidgets);

    // Cancelling writes nothing.
    await tester.tap(find.text(l.actionCancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the period filter narrows the history', (tester) async {
    await pumpScreen(tester);

    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    // Open the search bar's filter menu and pick Today.
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.today).last);
    await tester.pumpAndSettle();

    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#1'), findsNothing,
        reason: 'last year\'s report is outside today');
  });

  testWidgets('no history at all still says so', (tester) async {
    await pumpScreen(tester, reports: const []);

    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text(l.noZReportsYet), findsOneWidget);
  });
}

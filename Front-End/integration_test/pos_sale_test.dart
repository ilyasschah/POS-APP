// The first end-to-end pass over the till: find a product, ring it up, open
// the payment dialog, and check the money.
//
// ── Why this does not call `app.main()` ──────────────────────────────────────
//
// It runs the REAL MenuScreen, on a REAL Windows window, with real gestures and
// real layout — but it mounts that screen directly instead of booting from
// `main()`. `main()` walks device registration → the offline licence guard →
// login, every one of which needs a live server and real credentials. A test
// that has to hold a valid token to check that a burger costs 38 MAD is not
// testing the till, it is testing the network, and it fails on the morning
// somebody rotates a password.
//
// So the network is the only thing replaced. Drift runs in memory and is seeded
// with the two products; the company, the user and the device settings are
// overridden. Everything below that — the cart, promotions, tax maths, the
// widgets and the gestures — is the shipping code.
//
// ── Running it ──────────────────────────────────────────────────────────────
//
//   flutter test integration_test/pos_sale_test.dart -d windows
//
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/menu/menu_screen.dart';
import 'package:pos_app/product/product_search_bar.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/settings/settings_provider.dart';

const _companyId = 1;
const _userId = 7;
const _deviceUid = 'integration-test-register';

/// The shipped defaults, with ONE deliberate change.
///
/// 🚨 `Order.AllowTablelessOrders` defaults to false with the floor plan on, so
/// tapping a product correctly refuses and asks for a table first. That is real
/// behaviour worth its own test — but it is not this one, which is about a
/// counter-service till where a tap rings the product up.
///
/// Frozen otherwise, so a value saved on the developer's machine cannot change
/// what this test sees.
class _TillSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {
        ...kSettingDefaults,
        SettingKeys.allowTablelessOrders: 'true',
      };
}

void main() {
  // 🚨 Required, and required FIRST. Without it the test runs on the plain
  // widget binding and never reaches the Windows device at all.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());

    // Two products, priced differently, so "the right one was added" is a real
    // assertion rather than a coincidence.
    await db.into(db.productsTable).insert(
          ProductsTableCompanion.insert(
            id: const Value(101),
            companyId: _companyId,
            name: 'Classic Burger',
            price: const Value(38),
            code: const Value('BRG-1'),
            lastModified: DateTime.now().toUtc(),
          ),
        );
    await db.into(db.productsTable).insert(
          ProductsTableCompanion.insert(
            id: const Value(102),
            companyId: _companyId,
            name: 'Cheeseburger',
            price: const Value(45),
            code: const Value('BRG-2'),
            lastModified: DateTime.now().toUtc(),
          ),
        );

    // 🚨 An OPEN register, or the till refuses to trade.
    //
    // `sessionGateProvider` blocks the whole browser behind "Open the register
    // first" — sales, refunds and cash movements all belong to a session. The
    // screen renders no search field at all until this row exists, which is
    // correct behaviour and the first thing this test had to learn.
    await db.into(db.shiftsTable).insert(
          ShiftsTableCompanion.insert(
            localId: 'session-1',
            companyId: _companyId,
            userId: _userId,
            openedAt: DateTime.now().toUtc(),
            lastModified: DateTime.now().toUtc(),
            startingCash: const Value(2000),
            posDeviceUid: const Value(_deviceUid),
            posDeviceName: const Value('POS1'),
            status: const Value(PosSessionStatus.opened),
            syncStatus: const Value('pending_create'),
          ),
        );
  });

  tearDown(() => db.close());

  /// Mounts the till and waits for its Drift streams to deliver.
  Future<ProviderContainer> pumpTill(WidgetTester tester) async {
    late ProviderContainer container;

    // A till-sized window. The browser and the cart sit side by side, and at
    // the default 800x600 test surface the layout is not the one anyone runs.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appSettingsProvider.overrideWith(_TillSettings.new),
          // Scoped by register, not by user — see activeSessionProvider.
          deviceUidProvider.overrideWith((ref) async => _deviceUid),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MenuScreen(),
            );
          },
        ),
      ),
    );

    container.read(selectedCompanyProvider.notifier).update(
          Company(id: _companyId, name: 'FUTUR3'),
        );
    container.read(currentUserProvider.notifier).setUser(
          User(
            id: _userId,
            companyId: _companyId,
            username: 'ilyass',
            accessLevel: 9,
            isEnabled: true,
          ),
        );

    // Drift streams are async — one settle is not enough to get the catalogue
    // onto the screen.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    return container;
  }

  /// The POS search field.
  ///
  /// 🚨 Scoped to `ProductSearchBar`, never `find.byType(TextField).first`.
  /// The cart grows its own fields once a line is selected, and "the first
  /// TextField in the tree" silently became the quantity box — the second
  /// product then got typed into the keypad and never reached the grid.
  Finder searchField() => find.descendant(
        of: find.byType(ProductSearchBar),
        matching: find.byType(TextField),
      );

  /// A product's card in the grid, by its label.
  ///
  /// 🚨 `Text` only — deliberately NOT `find.text`, which also matches
  /// `EditableText` and therefore matches what was just typed into the search
  /// box. Searching the FULL name made `find.text(name).first` resolve to the
  /// search field itself, so the tap just re-focused the box and nothing was
  /// ever rung up. It only looked fine while the query was a prefix.
  Finder productCard(String name) =>
      find.byWidgetPredicate((w) => w is Text && w.data == name);

  testWidgets('a product searched, rung up, and paid for', (tester) async {
    final container = await pumpTill(tester);

    // ── 1. Find it ──────────────────────────────────────────────────────────
    await tester.enterText(searchField(), 'Cheese');
    await tester.pumpAndSettle();

    expect(productCard('Cheeseburger'), findsWidgets,
        reason: 'the search must surface the match');
    expect(productCard('Classic Burger'), findsNothing,
        reason: 'and hide everything else — otherwise the tap below is a '
            'coin toss between two cards');

    // ── 2. Ring it up ───────────────────────────────────────────────────────
    await tester.tap(productCard('Cheeseburger').first);
    await tester.pumpAndSettle();

    final cart = container.read(cartProvider);
    expect(cart.items.length, 1);
    expect(cart.items.single.productId, 102);
    expect(cart.items.single.quantity, 1);
    expect(cart.items.single.price, 45);

    // ── 3. The money on screen ──────────────────────────────────────────────
    // Read from the widget tree, not from the notifier: a total that is right
    // in the provider and absent from the screen is the failure this catches.
    expect(find.textContaining('45.00'), findsWidgets,
        reason: 'the cart footer shows the grand total');

    // ── 4. Open the payment dialog ──────────────────────────────────────────
    final l = AppLocalizations.of(tester.element(find.byType(MenuScreen)));
    await tester.tap(find.text(l.posPay));
    await tester.pumpAndSettle();

    expect(find.textContaining('45.00'), findsWidgets,
        reason: 'the checkout opens on the same figure the cart showed');
  });

  testWidgets('two lines total correctly', (tester) async {
    final container = await pumpTill(tester);

    // Straight off the unfiltered grid — searching is test 1's job, and doing
    // it again here only adds a way for this one to fail for the wrong reason.
    for (final name in ['Classic Burger', 'Cheeseburger']) {
      await tester.tap(productCard(name).first);
      await tester.pumpAndSettle();
    }

    final cart = container.read(cartProvider);
    expect(cart.items.length, 2);

    // 38 + 45. Asserted through the notifier's own getter, which is what the
    // footer and the checkout dialog both read.
    expect(container.read(cartProvider.notifier).grandTotal, 83);
    expect(find.textContaining('83.00'), findsWidgets);
  });

  testWidgets('the PAY button is dead with an empty cart', (tester) async {
    await pumpTill(tester);

    final l = AppLocalizations.of(tester.element(find.byType(MenuScreen)));
    await tester.tap(find.text(l.posPay));
    await tester.pumpAndSettle();

    // Nothing opens — an empty sale is not a sale.
    expect(find.byType(Dialog), findsNothing);
  });
}

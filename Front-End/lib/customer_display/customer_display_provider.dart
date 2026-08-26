import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_theme.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/customer_display/customer_display_state.dart';
import 'package:pos_app/customer_display/customer_display_web_server.dart';
import 'package:pos_app/l10n/app_locale.dart';
import 'package:pos_app/product/product_provider.dart';

class CustomerDisplayNotifier extends Notifier<CustomerDisplayState> {
  Timer? _resetTimer;

  // Product image cache: productId → raw base64 string (null = no image).
  // Images are small thumbnails; encoding once per product avoids re-reading
  // the file on every cart update.
  final Map<int, String?> _imgCache = {};

  @override
  CustomerDisplayState build() {
    ref.onDispose(() => _resetTimer?.cancel());
    return const CustomerDisplayState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  void syncFromCart({
    required CartState cartState,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
  }) {
    // Guard: never overwrite paymentPending or checkoutSuccess mid-flow.
    if (state.status == CustomerDisplayStatus.paymentPending ||
        state.status == CustomerDisplayStatus.checkoutSuccess) {
      return;
    }

    final company  = ref.read(selectedCompanyProvider);
    final currency = ref.read(currencySymbolProvider);
    final welcome  = _welcomeText;

    if (cartState.items.isEmpty) {
      state = CustomerDisplayState(
        status:      CustomerDisplayStatus.idle,
        currency:    currency,
        companyName: company?.name ?? '',
        companyLogo: company?.logo,
        welcomeText: welcome,
      );
    } else {
      state = CustomerDisplayState(
        status:      CustomerDisplayStatus.cartActive,
        items:       List.unmodifiable(cartState.items),
        subtotal:    subtotal,
        discount:    discount,
        tax:         tax,
        total:       total,
        currency:    currency,
        companyName: company?.name ?? '',
        companyLogo: company?.logo,
        welcomeText: welcome,
      );
    }

    _broadcast();
  }

  /// Called when the payment dialog opens.
  /// Transitions to paymentPending (internal guard) but keeps broadcasting
  /// the cart so the customer continues to see their items — not a "pay now"
  /// overlay. Only completeCheckout() flips to the success screen.
  void showPayment(double total) {
    _resetTimer?.cancel();
    final company = ref.read(selectedCompanyProvider);
    state = state.copyWith(
      status:      CustomerDisplayStatus.paymentPending,
      total:       total,
      companyName: company?.name ?? '',
      companyLogo: company?.logo,
    );
    _broadcast(); // still broadcasts {type:'cart'} for paymentPending
  }

  /// Called only after the local DB write commits — shows success screen.
  void completeCheckout({
    required double total,
    required double amountPaid,
    required double changeDue,
  }) {
    _resetTimer?.cancel();
    final company  = ref.read(selectedCompanyProvider);
    final currency = ref.read(currencySymbolProvider);
    final welcome  = _welcomeText;

    state = CustomerDisplayState(
      status:      CustomerDisplayStatus.checkoutSuccess,
      total:       total,
      amountPaid:  amountPaid,
      changeDue:   changeDue,
      currency:    currency,
      companyName: company?.name ?? '',
      companyLogo: company?.logo,
      welcomeText: welcome,
    );
    _broadcast();

    _resetTimer = Timer(const Duration(seconds: 6), () {
      state = CustomerDisplayState(
        status:      CustomerDisplayStatus.idle,
        currency:    currency,
        companyName: company?.name ?? '',
        companyLogo: company?.logo,
        welcomeText: welcome,
      );
      _broadcast();
    });
  }

  /// Called when the payment dialog is cancelled — returns to cart view
  /// (or idle if cart was somehow cleared) instead of staying on paymentPending.
  ///
  /// 🚨 Guarded on `ref.mounted`, because the only caller DEFERS it: the dialog's
  /// `dispose` cannot mutate provider state inline, so it hands this to a
  /// microtask. If the scope goes away before that microtask runs — the app
  /// closing on an open payment dialog, or a test tearing its container down —
  /// the notifier is already disposed and writing `state` throws. The timer is
  /// still cancelled either way; there is simply no display left to tell.
  void cancelPayment() {
    _resetTimer?.cancel();
    if (!ref.mounted) return;
    if (state.items.isNotEmpty) {
      state = state.copyWith(status: CustomerDisplayStatus.cartActive);
      _broadcast();
    } else {
      resetToIdle();
    }
  }

  void resetToIdle() {
    _resetTimer?.cancel();
    final company  = ref.read(selectedCompanyProvider);
    final currency = ref.read(currencySymbolProvider);
    state = CustomerDisplayState(
      status:      CustomerDisplayStatus.idle,
      currency:    currency,
      companyName: company?.name ?? '',
      companyLogo: company?.logo,
      welcomeText: _welcomeText,
    );
    _broadcast();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  String get _welcomeText =>
      ref.read(appSettingsProvider)[SettingKeys.customerDisplayWelcomeMessage] ??
      'WELCOME!';

  /// Configurable checkout-success message. Empty falls back to the localized
  /// "Thank you" string (resolved without a BuildContext via [l10nOf]).
  String get _thankYouText {
    final custom =
        ref.read(appSettingsProvider)[SettingKeys.customerDisplayThankYouMessage]
            ?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return l10nOf(ref).thankYou;
  }

  /// Theme colours for the web display (browsers can't read `Theme.of`), so the
  /// page renders in the operator's exact app theme.
  Map<String, String> get _themeMap => customerDisplayThemeMap(currentAppTheme(ref));

  bool get _webEnabled =>
      ref.read(appSettingsProvider)[SettingKeys.customerDisplayWebEnabled]
              ?.toLowerCase() ==
          'true' &&
      CustomerDisplayWebServer.instance.isRunning;

  void _broadcast() {
    if (!_webEnabled) return;
    final s  = state;
    final co = {'name': s.companyName, 'logo': s.companyLogo};
    final theme = _themeMap;

    switch (s.status) {
      case CustomerDisplayStatus.idle:
        CustomerDisplayWebServer.instance.broadcast({
          'type':        'idle',
          'company':     co,
          'welcomeText': s.welcomeText,
          'theme':       theme,
        });

      // Both cartActive and paymentPending broadcast the live cart.
      // paymentPending is only an internal guard — the customer must never see
      // a "processing payment" overlay; they verify their items until the
      // cashier confirms checkout.
      case CustomerDisplayStatus.cartActive:
      case CustomerDisplayStatus.paymentPending:
        CustomerDisplayWebServer.instance.broadcast({
          'type':     'cart',
          'company':  co,
          'currency': s.currency,
          'theme':    theme,
          'items':    s.items.map((i) => {
            'name':     i.productName,
            'qty':      i.quantity,
            'price':    i.price,
            'discount': i.discount + i.promotionalDiscount,
            'lineTotal':
                (i.price - i.discount - i.promotionalDiscount) * i.quantity,
            'image':    _productImage(i.productId), // base64 or null
          }).toList(),
          'subtotal': s.subtotal,
          'discount': s.discount,
          'tax':      s.tax,
          'total':    s.total,
        });

      case CustomerDisplayStatus.checkoutSuccess:
        CustomerDisplayWebServer.instance.broadcast({
          'type':        'success',
          'company':     co,
          'currency':    s.currency,
          'total':       s.total,
          'cash':        s.amountPaid,
          'change':      s.changeDue,
          'thankYouText': _thankYouText,
          'theme':       theme,
        });
    }
  }

  /// Returns a raw base64-encoded image string for the given product, or null
  /// if the product has no image. Results are cached per productId so disk
  /// I/O only happens once per product per app session.
  String? _productImage(int productId) {
    if (_imgCache.containsKey(productId)) return _imgCache[productId];
    try {
      final product = ref.read(productMapProvider)[productId];
      if (product == null) { _imgCache[productId] = null; return null; }
      final bytes = product.imageBytes;
      if (bytes == null || bytes.isEmpty) { _imgCache[productId] = null; return null; }
      final encoded = base64Encode(bytes);
      _imgCache[productId] = encoded;
      return encoded;
    } catch (_) {
      _imgCache[productId] = null;
      return null;
    }
  }
}

final customerDisplayProvider =
    NotifierProvider<CustomerDisplayNotifier, CustomerDisplayState>(
  CustomerDisplayNotifier.new,
);

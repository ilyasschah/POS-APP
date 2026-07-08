import 'package:pos_app/cart/checkout_models.dart';

enum CustomerDisplayStatus { idle, cartActive, paymentPending, checkoutSuccess }

class CustomerDisplayState {
  final CustomerDisplayStatus status;
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double amountPaid;
  final double changeDue;
  final String currency;
  final String companyName;
  final String? companyLogo;
  final String welcomeText;

  const CustomerDisplayState({
    this.status = CustomerDisplayStatus.idle,
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
    this.amountPaid = 0,
    this.changeDue = 0,
    this.currency = '',
    this.companyName = '',
    this.companyLogo,
    this.welcomeText = 'WELCOME!',
  });

  CustomerDisplayState copyWith({
    CustomerDisplayStatus? status,
    List<CartItem>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    double? amountPaid,
    double? changeDue,
    String? currency,
    String? companyName,
    String? companyLogo,
    String? welcomeText,
  }) {
    return CustomerDisplayState(
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      changeDue: changeDue ?? this.changeDue,
      currency: currency ?? this.currency,
      companyName: companyName ?? this.companyName,
      companyLogo: companyLogo ?? this.companyLogo,
      welcomeText: welcomeText ?? this.welcomeText,
    );
  }
}

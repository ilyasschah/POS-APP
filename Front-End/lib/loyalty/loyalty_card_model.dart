import 'package:pos_app/database/app_database.dart';

class LoyaltyCard {
  final int id;
  final int companyId;
  final int customerId;
  final String customerName;
  final String? cardNumber;
  final double points;
  final DateTime lastModified;
  final String syncStatus;

  const LoyaltyCard({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.customerName,
    this.cardNumber,
    required this.points,
    required this.lastModified,
    required this.syncStatus,
  });

  static LoyaltyCard fromJoin(
    LoyaltyCardsTableData card,
    CustomersTableData? customer,
  ) {
    return LoyaltyCard(
      id: card.id,
      companyId: card.companyId,
      customerId: card.customerId,
      customerName: customer?.name ?? 'Unknown',
      cardNumber: card.cardNumber,
      points: card.points,
      lastModified: card.lastModified,
      syncStatus: card.syncStatus,
    );
  }
}

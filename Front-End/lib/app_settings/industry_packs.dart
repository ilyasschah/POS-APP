/// Hardcoded industry pack definitions.
///
/// Each pack supplies:
///   - [getOrderTypes]    → list of order-type labels (index = CartState.serviceType)
///   - [getServiceStatuses] → list of status maps with id, label, color string
class IndustryPacks {
  IndustryPacks._();

  static const List<String> packNames = ['Restaurant', 'Salon', 'Hotel'];

  static List<String> getOrderTypes(String pack) {
    switch (pack) {
      case 'Salon':
        return ['In-Salon', 'House Call', 'Event / Wedding'];
      case 'Hotel':
        return ['Room Service', 'Bar', 'Poolside'];
      case 'Restaurant':
      default:
        return ['Dine-In', 'Takeaway', 'Delivery'];
    }
  }

  /// ALL-CAPS prefixes used in order numbers (index == CartState.serviceType).
  /// serviceType 0 is always the "default" order type for the pack.
  static List<String> getPrefixes(String pack) {
    switch (pack) {
      case 'Salon':
        return ['ORDER', 'HOUSE CALL', 'EVENT'];
      case 'Hotel':
        return ['ORDER', 'BAR', 'POOLSIDE'];
      case 'Restaurant':
      default:
        return ['ORDER', 'TAKEAWAY', 'DELIVERY'];
    }
  }

  static List<Map<String, dynamic>> getServiceStatuses(String pack) {
    switch (pack) {
      case 'Salon':
        return [
          {'id': 1, 'label': 'Waiting in Lobby', 'color': 'orange'},
          {'id': 2, 'label': 'In Chair',          'color': 'blue'},
          {'id': 3, 'label': 'Finished',           'color': 'green'},
        ];
      case 'Hotel':
        return [
          {'id': 1, 'label': 'Reserved',        'color': 'blue'},
          {'id': 2, 'label': 'Checked-In',      'color': 'purple'},
          {'id': 3, 'label': 'Needs Cleaning',  'color': 'orange'},
          {'id': 4, 'label': 'Available',       'color': 'green'},
        ];
      case 'Restaurant':
      default:
        return [
          {'id': 1, 'label': 'Seated',        'color': 'blue'},
          {'id': 2, 'label': 'In Kitchen',    'color': 'orange'},
          {'id': 3, 'label': 'Ready to Pay',  'color': 'green'},
        ];
    }
  }
}

/// Why an update must not be installed *right now*.
///
/// Installing means closing the app and replacing its files, so anything the
/// terminal is holding that is not on disk or not yet on the server is at risk.
/// The rules live here as a pure function so they can be tested without a cart,
/// a database or a network.
library;

enum UpdateBlocker {
  /// 🚨 The cashier has items in the cart right now.
  ///
  /// This is the one that loses money. Tapping a floor-plan table creates NO
  /// `pos_orders` row — the order is materialised in Drift only at checkout — so
  /// an in-progress cart lives in memory alone and is gone the moment the app
  /// exits. No database check can see it, which is exactly why it is checked
  /// separately from [unsyncedWork].
  activeCart,

  /// Local rows the server has not accepted yet.
  ///
  /// These SURVIVE the update — they are on disk, and the new build reads the
  /// same database — so this only warns. It is still worth saying: an operator
  /// about to restart a till would rather push first.
  unsyncedWork,
}

/// Whether a blocker stops the update or merely warns about it.
extension UpdateBlockerSeverity on UpdateBlocker {
  /// True when the operator must resolve it before installing.
  bool get isFatal => switch (this) {
        UpdateBlocker.activeCart => true,
        UpdateBlocker.unsyncedWork => false,
      };
}

/// Evaluates the pre-install checks.
///
/// [cartItemCount] is the LIVE cart (memory), [pendingPushCount] is rows waiting
/// to sync (disk). Returns every blocker found, most severe first.
List<UpdateBlocker> evaluateUpdateBlockers({
  required int cartItemCount,
  required int pendingPushCount,
}) {
  return [
    if (cartItemCount > 0) UpdateBlocker.activeCart,
    if (pendingPushCount > 0) UpdateBlocker.unsyncedWork,
  ];
}

/// True when nothing fatal stands in the way. Warnings do not block.
bool canInstallUpdate(List<UpdateBlocker> blockers) =>
    !blockers.any((b) => b.isFatal);

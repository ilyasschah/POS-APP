/// Canonical `syncStatus` values for local Drift rows, and the ONE invariant
/// that ties them together. **Read this before writing any offline row's
/// `syncStatus`.**
///
/// ## Why there are two "pending" families
///
/// A locally-written row reaches the server by ONE of two paths, selected purely
/// by its status string:
///
/// * [pending] — a **checkout or refund artifact** (a sales/refund `Document`,
///   its `DocumentItem`s, its `Payment`, its `discount_lines`). These are NEVER
///   pushed by the generic `pushPending<Entity>Ops` methods. They are created
///   server-side as a side effect of the PosOrder `/PosOrder/BatchSync` push
///   (checkout) or the `/Document/Refund` push (refund), and then reconciled back
///   to the local row by document number. `pushPendingDocuments` /
///   `pushPendingPayments` deliberately **exclude** [pending].
///
/// * [pendingCreate] / [pendingUpdate] / [pendingDelete] — a **manually**
///   created / edited / soft-deleted entity (the document editor, products,
///   customers, taxes, …). These ARE drained by the matching
///   `pushPending<Entity>Ops`, which POST / PATCH / DELETE the row directly and
///   remap temp negative ids to real server ids.
///
/// ⚠️ **The trap:** writing a checkout/refund `Document` or `Payment` as
/// [pendingCreate] makes `pushPendingDocuments` / `pushPendingPayments` POST it a
/// SECOND time — a silent double-create on the server (duplicate document +
/// duplicate payment). Anything that syncs via the order/refund command path must
/// be written as [pending].
class SyncStatuses {
  const SyncStatuses._();

  /// Synced to (or pulled from) the server — no pending work.
  static const synced = 'synced';

  /// Checkout / refund artifact. Syncs via the order/refund command path, NOT the
  /// generic pushers. See the invariant above.
  static const pending = 'pending';

  /// Manually created row (carries a temp negative id) — drained by the generic
  /// pusher via POST, then temp→real id remap.
  static const pendingCreate = 'pending_create';

  /// Manually edited row — drained by the generic pusher via PATCH.
  static const pendingUpdate = 'pending_update';

  /// Manually soft-deleted row — drained by the generic pusher via DELETE.
  static const pendingDelete = 'pending_delete';

  /// A push attempt failed definitively; surfaced for manual review.
  static const failed = 'failed';
}

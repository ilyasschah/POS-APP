/// Single source of truth for DocumentType IDs and series codes.
/// IDs must match the DocumentType table; codes drive YY-CCC-NNNNNN numbering.
abstract final class DocumentTypes {
  // ── IDs ───────────────────────────────────────────────────────────────────
  static const int purchase       = 1;
  static const int sales          = 2;
  static const int inventoryCount = 3;
  static const int refund         = 4;
  static const int stockReturn    = 5;
  static const int lossAndDamage  = 6;
  static const int proforma       = 7;

  // ── Series codes (used in document numbering: YY-{code}-NNNNNN) ──────────
  static const String purchaseCode        = '100';
  static const String salesCode           = '200';
  static const String inventoryCountCode  = '300';
  static const String refundCode          = '220';
  static const String stockReturnCode     = '120';
  static const String lossAndDamageCode   = '400';
  static const String proformaCode        = '230';
}

/// Single source of truth for DocumentCategory IDs.
abstract final class DocumentCategories {
  static const int expenses  = 1;
  static const int sales     = 2;
  static const int inventory = 3;
  static const int loss      = 4;
}

/// `DocumentType.StockDirection` — which way a type's lines move goods. Mirrors
/// the server's column; every stock rule reads it rather than a list of ids.
abstract final class StockDirections {
  static const int none       = 0;
  static const int intoStock  = 1;
  static const int outOfStock = 2;
}

/// Paid-status values stored on the document record.
abstract final class PaidStatus {
  static const int unpaid  = 0;
  static const int paid    = 1;
  static const int partial = 2;
  static const int voided  = 99;
}

namespace Api.Constants
{
    /// <summary>
    /// Single source of truth for DocumentType IDs and their number-series codes.
    /// IDs must match the DocumentType table; codes drive the YY-CCC-NNNNNN numbering scheme.
    /// </summary>
    public static class DocumentTypeConstants
    {
        // ── IDs (match DocumentType.Id in the database) ──────────────────────
        public const int Purchase       = 1;
        public const int Sales          = 2;
        public const int InventoryCount = 3;
        public const int Refund         = 4;
        public const int StockReturn    = 5;
        public const int LossAndDamage  = 6;
        public const int Proforma       = 7;

        // ── Series codes (used in document numbering: YY-{Code}-NNNNNN) ──────
        public const string PurchaseCode        = "100";
        public const string SalesCode           = "200";
        public const string InventoryCountCode  = "300";
        public const string RefundCode          = "220";
        public const string StockReturnCode     = "120";
        public const string LossAndDamageCode   = "400";
        public const string ProformaCode        = "230";
    }

    /// <summary>
    /// Single source of truth for DocumentCategory IDs.
    /// </summary>
    public static class DocumentCategoryConstants
    {
        public const int Expenses  = 1;
        public const int Sales     = 2;
        public const int Inventory = 3;
        public const int Loss      = 4;
    }

    /// <summary>
    /// Paid-status codes stored on the Document.PaidStatus column.
    /// </summary>
    public static class PaidStatusConstants
    {
        public const int Unpaid  = 0;
        public const int Paid    = 1;
        public const int Partial = 2;
        public const int Voided  = 99;
    }
}

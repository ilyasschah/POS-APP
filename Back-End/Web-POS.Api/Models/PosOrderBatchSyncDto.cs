namespace Api.Models
{
    /// <summary>
    /// Request body for POST /PosOrder/BatchSync.
    /// Each item carries the order header, its line items, and a client-generated
    /// LocalId (UUID). LocalId is never persisted server-side — it's echoed back
    /// so the Flutter sync engine can match server IDs to local Drift rows.
    /// </summary>
    public class BatchSyncPosOrdersRequest
    {
        public required List<BatchSyncOrderItem> Orders { get; set; }
    }

    public class BatchSyncOrderItem
    {
        public required string LocalId { get; set; }
        public required CreatePosOrderRequest Order { get; set; }
        public List<BulkAddPosOrderItemRequest> Items { get; set; } = new();
        public decimal OrderTotal { get; set; }

        /// Normalized discount breakdown captured at checkout, forwarded into the
        /// CheckoutPosOrderRequest so DiscountLine rows are persisted server-side.
        public List<DiscountLineDto> Discounts { get; set; } = new();

        /// <summary>
        /// Set when the client completed an existing open order that was
        /// originally created on the server (e.g. the row whose local sentinel
        /// id is "svr_3280").  The handler calls PosOrders/Checkout on this id
        /// instead of creating a new PosOrder, preventing duplicate rows.
        /// </summary>
        public int? ExistingServerId { get; set; }

        /// Payment details — required when ExistingServerId is set.
        public int? PaymentTypeId { get; set; }
        public decimal? AmountPaid { get; set; }

        /// Device-local document number the client issued offline at checkout
        /// (e.g. "CAISSE1-200-000045"). When present, checkout keeps it verbatim
        /// instead of generating a server-side YY-CCC-NNNNNN number, so the
        /// printed/scanned receipt number never changes after sync.
        public string? ClientDocumentNumber { get; set; }

        /// The POS session's client localId, sent by the device with every
        /// order. Without this property the field arrived on the wire and was
        /// silently dropped, which is why sessions banked no takings at all.
        public string? SessionLocalId { get; set; }
    }

    public class BatchSyncPosOrdersResponse
    {
        public List<BatchSyncResult> Results { get; set; } = new();
    }

    public class BatchSyncResult
    {
        public string LocalId { get; set; } = string.Empty;
        public int? ServerId { get; set; }
        public bool Success { get; set; }
        public string? Error { get; set; }
        public List<string> Warnings { get; set; } = new();

        /// Created DocumentItem server ids keyed by the client's per-line LineLocalId
        /// (the Drift document_item localId). Empty for orders that stayed open
        /// (no checkout) or whose items carried no LineLocalId.
        public Dictionary<string, int> ItemServerIds { get; set; } = new();
    }
}

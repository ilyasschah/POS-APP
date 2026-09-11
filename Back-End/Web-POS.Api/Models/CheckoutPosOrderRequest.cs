namespace Api.Models
{
    public class CheckoutPosOrderRequest
    {
        public required int PosOrderId { get; set; }
        public required int PaymentTypeId { get; set; }
        public required decimal AmountPaid { get; set; }
        public required decimal GrandTotal { get; set; }
        public required int DocumentTypeId { get; set; }
        public required int WarehouseId { get; set; }
        public required List<CheckoutItemDto> Items { get; set; }
        public string? OrderNumber { get; set; }

        /// Normalized discount breakdown for this sale (manual item/cart,
        /// promotion, customer profile, loyalty points). Persisted as DiscountLine
        /// rows linked to the created Document. Empty for legacy/online callers.
        public List<DiscountLineDto> Discounts { get; set; } = new();

        /// Device-local document number the client issued offline. When set,
        /// checkout uses it verbatim instead of generating a YY-CCC-NNNNNN
        /// number — so the offline receipt number survives sync unchanged.
        public string? ClientDocumentNumber { get; set; }

        /// The tenders that settled this sale, when there is more than one — a
        /// split bill, where each guest pays their share of the same document.
        /// Empty means the classic single tender in PaymentTypeId / AmountPaid,
        /// which every existing caller still sends.
        public List<CheckoutPaymentDto> Payments { get; set; } = new();

        /// The POS session's CLIENT localId — never a server id.
        ///
        /// A sale rung up offline belongs to a session that may itself have been
        /// opened offline, so the UUID is the only handle both sides share at
        /// write time. Null means "no session": the sale is banked unattached
        /// rather than refused, because the money has already changed hands.
        public string? SessionLocalId { get; set; }
    }

    /// <summary>One tender on a split bill: what one guest paid, and how.</summary>
    public class CheckoutPaymentDto
    {
        public int PaymentTypeId { get; set; }
        public decimal Amount { get; set; }
    }

    public class CheckoutItemDto
    {
        public required int ProductId { get; set; }
        public required decimal PriceBeforeTaxAfterDiscount { get; set; }
        public required decimal PriceAfterDiscount { get; set; }
        public required decimal Total { get; set; }
        public required decimal TotalAfterDocumentDiscount { get; set; }
        // Client's stable line id (Drift document_item localId). Optional: the
        // online checkout path doesn't set it. When present, checkout returns the
        // created DocumentItem's server id keyed by this value so the offline
        // client can stamp its local document_items row (enabling later edit/delete
        // sync). It also disambiguates duplicate-product lines from each other.
        public string? LineLocalId { get; set; }
        public List<CheckoutItemTaxDto> Taxes { get; set; } = new List<CheckoutItemTaxDto>();

        /// The modifier options this line was sold with, snapshotted by the
        /// client. Persisted as DocumentItemModifier rows against the created
        /// line. Empty for every caller that predates modifiers, which is why
        /// nothing here is required.
        public List<ModifierSnapshotDto> Modifiers { get; set; } = new();
    }

    /// Result of a checkout: the created Document's id plus a map of each item's
    /// client LineLocalId → the server DocumentItem id. The map is empty for
    /// callers that don't send LineLocalId (online checkout).
    public class CheckoutResult
    {
        public int DocumentId { get; set; }
        public Dictionary<string, int> ItemServerIds { get; set; } = new();
    }

    public class CheckoutItemTaxDto
    {
        public required int TaxId { get; set; }
        public required decimal Amount { get; set; }
    }
}
namespace Api.Models
{
    public class PosOrderItemDto
    {
        public int Id { get; set; }
        public int PosOrderId { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; } = string.Empty;
        public int RoundNumber { get; set; }
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public bool IsLocked { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public int DiscountAppliedType { get; set; }
        /// The per-item discount as the operator ENTERED it (10 + type 0 = "10%")
        /// while Discount holds the resolved per-unit money. See
        /// PosOrderItem.DiscountInputValue — null means "not recorded", and the
        /// client falls back to Discount.
        public decimal? DiscountInputValue { get; set; }
        public int? DiscountInputType { get; set; }
        public bool IsFeatured { get; set; }
        public int? VoidedBy { get; set; }
        public string? VoidedByUserName { get; set; }
        public string? Comment { get; set; }
        public DateTime DateCreated { get; set; }
        public string? Bundle { get; set; }
        public List<PosOrderItemTaxDto> Taxes { get; set; } = new List<PosOrderItemTaxDto>();

        /// The chosen modifier options, in the order the cashier was asked.
        /// Empty on a line that has none — which is most of them.
        public List<ModifierSnapshotDto> Modifiers { get; set; } = new();
    }
    public class PosOrderItemTaxDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal Rate { get; set; }
        public bool IsFixed { get; set; }
        public bool IsTaxOnTotal { get; set; }
    }
    public class CreatePosOrderItemRequest
    {
        public required int PosOrderId { get; set; }
        public required int ProductId { get; set; }
        public int RoundNumber { get; set; }
        public required decimal Quantity { get; set; }
        public required decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public int DiscountAppliedType { get; set; }
        public string? Comment { get; set; }
        public string? Bundle { get; set; }
    }
    public class BatchSyncItemTaxDto
    {
        public int TaxId { get; set; }
        public decimal Amount { get; set; }
    }

    public class BulkAddPosOrderItemRequest
    {
        public int PosOrderId { get; set; }
        public int ProductId { get; set; }
        // Client-generated stable line id (the Drift document_item localId, shared
        // with the pos_order_item). Never persisted on PosOrderItem — it is only
        // forwarded into CheckoutItemDto so checkout can echo the created
        // DocumentItem's server id back, keyed by this line, for offline linking.
        public string? LineLocalId { get; set; }
        public int RoundNumber { get; set; }
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public string? Comment { get; set; }
        public string? Bundle { get; set; }
        public int DiscountAppliedType { get; set; }
        /// The per-item discount as the operator ENTERED it (10 + type 0 = "10%")
        /// while Discount holds the resolved per-unit money. See
        /// PosOrderItem.DiscountInputValue — null means "not recorded", and the
        /// client falls back to Discount.
        public decimal? DiscountInputValue { get; set; }
        public int? DiscountInputType { get; set; }
        public List<int> AppliedTaxIds { get; set; } = new List<int>();
        // Per-item tax amounts from offline checkout. Populated by the Flutter
        // client so BatchSync can pass them to CheckoutItemDto.Taxes and create
        // DocumentItemTax rows server-side.
        public List<BatchSyncItemTaxDto> Taxes { get; set; } = new List<BatchSyncItemTaxDto>();

        /// The chosen modifier options for this line, snapshotted by the client.
        /// Persisted as PosOrderItemModifier rows so a parked order opened on
        /// ANOTHER till still knows what it is making — without them the second
        /// device sees the right price and a plain burger.
        public List<ModifierSnapshotDto> Modifiers { get; set; } = new();
    }

    public class UpdatePosOrderItemRequest
    {
        public required int Id { get; set; }
        public required decimal Quantity { get; set; }
        public required decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public int DiscountAppliedType { get; set; }
        public string? Comment { get; set; }
    }
}
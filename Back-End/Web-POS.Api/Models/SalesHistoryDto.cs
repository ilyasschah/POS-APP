namespace Api.Models
{
    public class SalesHistoryDocumentDto
    {
        public int Id { get; set; }
        public string Number { get; set; } = string.Empty;
        public string? UserName { get; set; }
        public int? CustomerId { get; set; }
        public string? CustomerName { get; set; }
        public string? WarehouseName { get; set; }
        public string? OrderNumber { get; set; }
        public string? ReferenceDocumentNumber { get; set; }
        public DateTime Date { get; set; }
        public DateTime StockDate { get; set; }
        public DateTime DateCreated { get; set; }
        public decimal Total { get; set; }
        public decimal TotalBeforeTax { get; set; }
        public decimal TaxTotal { get; set; }
        public decimal Discount { get; set; }
        public int PaidStatus { get; set; }
        public string? PaymentSummary { get; set; }

        // Populated only when the caller requests includeItems=true (the
        // offline sync pull). Empty for the normal sales-history screen so its
        // payload stays lean.
        public List<SalesHistoryItemDto> Items { get; set; } = new();
    }

    public class SalesHistoryItemDto
    {
        /// <summary>
        /// The DocumentItem's own server id. The offline pull stores this as
        /// `document_items.serverId`; without it every pulled line landed with a
        /// null server id, so the offline editor could not update or delete a
        /// line that came from another terminal — its push had no id to target.
        /// </summary>
        public int Id { get; set; }
        public int ProductId { get; set; }
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal Total { get; set; }

        /// Net unit price. Already projected by the query for the tax rollup —
        /// surfaced here because the offline pull reads it to reconstruct
        /// per-line tax locally.
        public decimal PriceBeforeTax { get; set; }
    }
}

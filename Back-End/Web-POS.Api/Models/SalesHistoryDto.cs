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

        /// <summary>
        /// The document's type (2 = Sales, 4 = Refund, purchases/manual types
        /// otherwise). Always populated. The offline sync pull needs it because
        /// this endpoint is no longer sales-only — without the type the client
        /// cannot tell a pulled refund or purchase from a sale, and
        /// `document_items.total` means different things per origin (see the
        /// checkout-vs-manual rule in handoff §3).
        /// </summary>
        public int DocumentTypeId { get; set; }

        /// <summary>Warehouse the document was stocked against. Needed by the
        /// offline pull so a cross-device document isn't stored with
        /// warehouseId 0, which made it invisible to warehouse-scoped screens.</summary>
        public int WarehouseId { get; set; }

        /// <summary>Author of the document. Same reason as
        /// <see cref="WarehouseId"/> — the pull previously stored 0.</summary>
        public int UserId { get; set; }

        // Populated only when the caller requests includeItems=true (the
        // offline sync pull). Empty for the normal sales-history screen so its
        // payload stays lean.
        public List<SalesHistoryItemDto> Items { get; set; } = new();

        /// <summary>
        /// The document's payment rows, on the same includeItems=true condition.
        ///
        /// 🚨 There is no payment PULL anywhere in the client — `payments` had a
        /// push and nothing else — so a document created on one terminal reached
        /// every other one with ZERO payment rows. The sales-history "Paiement"
        /// column reads local payments, so another till's sale rendered "N/A";
        /// worse, the Z-report's breakdown-by-payment-type and the credit screen
        /// read the same table, so each terminal only ever counted its OWN sales.
        /// Returned here rather than via a new endpoint because this query
        /// already loads them to build <see cref="PaymentSummary"/>.
        /// </summary>
        public List<SalesHistoryPaymentDto> Payments { get; set; } = new();
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

    /// <summary>One payment against a document, for the offline sync pull.</summary>
    public class SalesHistoryPaymentDto
    {
        /// The server Payment.Id. Stored as `payments.serverId` so a pulled
        /// payment can later be edited or deleted from the document editor —
        /// without it the push would have no id to target.
        public int Id { get; set; }
        public int PaymentTypeId { get; set; }
        public decimal Amount { get; set; }
        public int UserId { get; set; }
        public DateTime? Date { get; set; }

        /// The session (Shift) this payment was taken in.
        ///
        /// Without it a pulled payment lands with no session at all, so the
        /// register's Payments tab shows nothing and its "Total taken" reads
        /// 0.00 — the figure the drawer is counted against. The client maps this
        /// server id back to its own session localId.
        public int? SessionId { get; set; }

        /// Non-null once the payment belongs to a closed Z-report. The client
        /// locks such payments against edit/delete, so it must cross too.
        public int? ZReportId { get; set; }
    }
}

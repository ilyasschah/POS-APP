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
        public int ProductId { get; set; }
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal Total { get; set; }
    }
}

namespace Api.Models
{
    public class SalesHistoryDocumentDto
    {
        public int Id { get; set; }
        public string Number { get; set; } = string.Empty;
        public string? UserName { get; set; }
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
    }
}

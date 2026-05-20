namespace Api.Models
{
    public class ZReportDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int Number { get; set; }
        public DateTime DateCreated { get; set; }

        public int FromDocumentId { get; set; }
        public int ToDocumentId { get; set; }

        public decimal TotalSales { get; set; }
        public decimal TotalReturns { get; set; }
        public decimal DiscountsGranted { get; set; }
        public decimal TaxableTotal { get; set; }
        public decimal TotalTax { get; set; }
        public decimal GrandTotal { get; set; }
        public decimal TotalCashIn { get; set; }
        public decimal TotalCashOut { get; set; }

        // Nested list to show the "Cash: $100, Credit: $50" breakdown
        public List<ZReportPaymentSummaryDto> PaymentSummaries { get; set; } = new();
    }

    public class ZReportPaymentSummaryDto
    {
        public int Id { get; set; }
        public int ZReportId { get; set; }
        public int PaymentTypeId { get; set; }
        public string? PaymentTypeName { get; set; } // Mapped from the PaymentType relation for the UI
        public decimal TotalAmount { get; set; }
    }
}
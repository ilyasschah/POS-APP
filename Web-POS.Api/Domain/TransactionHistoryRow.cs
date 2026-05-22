namespace Api.Domain
{
    public class TransactionHistoryRow
    {
        public int CompanyId { get; set; }
        public int? CustomerId { get; set; }
        public string? PartnerName { get; set; }
        public DateTime Date { get; set; }
        public string TransactionType { get; set; } = "";
        public string? RefNumber { get; set; }
        public decimal Credit { get; set; }
        public decimal Debit { get; set; }
    }
}

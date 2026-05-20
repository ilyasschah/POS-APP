namespace Api.Domain
{
    public class StockMovementRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int UserId { get; set; }
        public int ProductId { get; set; }
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal Quantity { get; set; }
    }
}

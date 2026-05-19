namespace Api.Domain
{
    public class DailySalesRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int? CustomerId { get; set; }
        public int UserId { get; set; }
        public int WarehouseId { get; set; }
        public decimal Amount { get; set; }
    }
}

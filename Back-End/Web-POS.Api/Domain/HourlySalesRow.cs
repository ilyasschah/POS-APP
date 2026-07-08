namespace Api.Domain
{
    public class HourlySalesRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int Hour { get; set; }
        public int? CustomerId { get; set; }
        public int WarehouseId { get; set; }
        public int DocumentId { get; set; }
        public decimal Amount { get; set; }
    }
}

namespace Api.Domain
{
    public class HourlySalesByGroupRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int Hour { get; set; }
        public int? CustomerId { get; set; }
        public int WarehouseId { get; set; }
        public int? ProductGroupId { get; set; }
        public string ProductGroup { get; set; } = "";
        public decimal Amount { get; set; }
    }
}

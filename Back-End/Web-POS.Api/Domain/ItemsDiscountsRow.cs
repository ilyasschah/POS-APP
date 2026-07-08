namespace Api.Domain
{
    public class ItemsDiscountsRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public int? WarehouseId { get; set; }
        public int ProductId { get; set; }
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public decimal TotalDiscount { get; set; }
    }
}

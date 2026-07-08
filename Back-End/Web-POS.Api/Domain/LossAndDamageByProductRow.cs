namespace Api.Domain
{
    public class LossAndDamageByProductRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int UserId { get; set; }
        public int WarehouseId { get; set; }
        public int ProductId { get; set; }
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public string UOM { get; set; } = "";
        public int? ProductGroupId { get; set; }
        public string? ProductGroupName { get; set; }
        public decimal Quantity { get; set; }
        public decimal TotalBeforeTax { get; set; }
        public decimal Total { get; set; }
    }
}

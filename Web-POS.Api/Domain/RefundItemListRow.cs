namespace Api.Domain
{
    public class RefundItemListRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public DateTime DateCreated { get; set; }
        public string DocumentNumber { get; set; } = "";
        public string? RefNumber { get; set; }
        public string? OrderNumber { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public int WarehouseId { get; set; }
        public string? CustomerCode { get; set; }
        public string CustomerName { get; set; } = "";
        public int ProductId { get; set; }
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public string UOM { get; set; } = "";
        public int? ProductGroupId { get; set; }
        public decimal Quantity { get; set; }
        public decimal TotalBeforeTax { get; set; }
        public decimal TotalTax { get; set; }
        public decimal Total { get; set; }
    }
}

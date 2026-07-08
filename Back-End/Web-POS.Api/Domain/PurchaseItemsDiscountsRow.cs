namespace Api.Domain
{
    public class PurchaseItemsDiscountsRow
    {
        public int CompanyId { get; set; }
        public int DocumentId { get; set; }
        public string DocumentNumber { get; set; } = "";
        public DateTime Date { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public int? WarehouseId { get; set; }
        public int ProductId { get; set; }
        public string? ProductCode { get; set; }
        public string ProductName { get; set; } = "";
        public string UserName { get; set; } = "";
        public string SupplierName { get; set; } = "";
        public decimal Quantity { get; set; }
        public decimal Cost { get; set; }
        public decimal TotalBeforeDiscount { get; set; }
        public decimal TotalAfterDiscount { get; set; }
        public decimal DiscountValue { get; set; }
        public int DiscountType { get; set; }
        public decimal TotalDiscount { get; set; }
    }
}

namespace Api.Domain
{
    public class PurchaseDiscountsRow
    {
        public int CompanyId { get; set; }
        public int DocumentId { get; set; }
        public string DocumentNumber { get; set; } = "";
        public DateTime Date { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public string UserName { get; set; } = "";
        public string SupplierName { get; set; } = "";
        public decimal TotalBeforeDiscount { get; set; }
        public decimal TotalAfterDiscount { get; set; }
        public decimal DiscountGranted { get; set; }
    }
}

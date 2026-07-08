namespace Api.Domain
{
    public class UnpaidPurchaseRow
    {
        public int CompanyId { get; set; }
        public int DocumentId { get; set; }
        public DateTime Date { get; set; }
        public DateTime? DueDate { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public int WarehouseId { get; set; }
        public string DocumentNumber { get; set; } = "";
        public string SupplierName { get; set; } = "";
        public decimal DocumentTotal { get; set; }
        public decimal TotalPaid { get; set; }
        public decimal TotalUnpaid { get; set; }
    }
}

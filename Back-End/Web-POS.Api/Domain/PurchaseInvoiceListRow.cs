namespace Api.Domain
{
    public class PurchaseInvoiceListRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int DocumentId { get; set; }
        public string DocumentNumber { get; set; } = "";
        public string? ExternalDocument { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public int? WarehouseId { get; set; }
        public string SupplierName { get; set; } = "";
        public decimal Total { get; set; }
    }
}

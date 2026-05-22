namespace Api.Domain
{
    public class PurchaseByTaxRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int? UserId { get; set; }
        public int? CustomerId { get; set; }
        public int? WarehouseId { get; set; }
        public int? ProductId { get; set; }
        public int? ProductGroupId { get; set; }
        public int? TaxId { get; set; }
        public string TaxName { get; set; } = "";
        public decimal TotalBeforeTax { get; set; }
        public decimal TaxAmount { get; set; }
        public decimal Total { get; set; }
    }
}

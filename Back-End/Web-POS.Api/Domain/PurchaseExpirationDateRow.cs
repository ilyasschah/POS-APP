using Microsoft.EntityFrameworkCore;

namespace Api.Domain
{
    [Keyless]
    public class PurchaseExpirationDateRow
    {
        public int    CompanyId      { get; set; }
        public DateTime Date         { get; set; }
        public int    DocumentId     { get; set; }
        public string DocumentNumber { get; set; } = "";
        public int    UserId         { get; set; }
        public int    CustomerId     { get; set; }
        public int    WarehouseId    { get; set; }
        public int    ProductId      { get; set; }
        public string? ProductCode   { get; set; }
        public string ProductName    { get; set; } = "";
        public string UOM            { get; set; } = "";
        public int?   ProductGroupId { get; set; }
        public decimal Quantity      { get; set; }
        public string SupplierName   { get; set; } = "";
        public DateTime ExpirationDate { get; set; }
    }
}

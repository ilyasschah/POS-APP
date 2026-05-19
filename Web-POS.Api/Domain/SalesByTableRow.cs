namespace Api.Domain
{
    public class SalesByTableRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public int WarehouseId { get; set; }
        public string OrderNumber { get; set; } = "";
        public int DocumentId { get; set; }
        public decimal Amount { get; set; }
    }
}

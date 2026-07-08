namespace Api.Domain
{
    public class InvoiceListRow
    {
        public int CompanyId { get; set; }
        public DateTime Date { get; set; }
        public string DocumentNumber { get; set; } = "";
        public int UserId { get; set; }
        public int? CustomerId { get; set; }
        public int WarehouseId { get; set; }
        public string CustomerName { get; set; } = "";
        public string PaymentMethodName { get; set; } = "";
        public decimal Total { get; set; }
    }
}

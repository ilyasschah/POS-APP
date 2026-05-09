namespace Api.Domain
{
    public class DashboardSalesDataView
    {
        public int CompanyId { get; set; }
        public int DocumentId { get; set; }
        public DateTime Date { get; set; }
        public int SalesYear { get; set; }
        public int SalesMonth { get; set; }
        public int SalesHour { get; set; }
        public int? ProductId { get; set; }
        public string? ProductName { get; set; }
        public decimal Quantity { get; set; }
        public decimal ItemTotal { get; set; }
        public int? ProductGroupId { get; set; }
        public string? ProductGroupName { get; set; }
        public int? CustomerId { get; set; }
        public string? CustomerName { get; set; }
    }
}
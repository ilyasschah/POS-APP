namespace Api.Models
{
    public class ProcessRefundRequest
    {
        public required string OriginalDocumentNumber { get; set; }
        public required int RefundPaymentTypeId { get; set; }
        public required int WarehouseId { get; set; }
        public List<RefundItemRequest> Items { get; set; } = new();
    }

    public class RefundItemRequest
    {
        public required int ProductId { get; set; }
        public required decimal Quantity { get; set; }
    }

    public class ProcessRefundResponse
    {
        public string RefundDocumentNumber { get; set; } = "";
        public decimal TotalRefunded { get; set; }
    }
}

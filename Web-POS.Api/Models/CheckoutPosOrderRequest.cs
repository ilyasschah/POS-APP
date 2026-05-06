namespace Api.Models
{
    public class CheckoutPosOrderRequest
    {
        public required int PosOrderId { get; set; }
        public required int PaymentTypeId { get; set; }
        public required decimal AmountPaid { get; set; }
        public required decimal GrandTotal { get; set; }
        public required int DocumentTypeId { get; set; }
        public required int WarehouseId { get; set; }
        public required List<CheckoutItemDto> Items { get; set; }
        public string? OrderNumber { get; set; }
    }

    public class CheckoutItemDto
    {
        public required int ProductId { get; set; }
        public required decimal PriceBeforeTaxAfterDiscount { get; set; }
        public required decimal PriceAfterDiscount { get; set; }
        public required decimal Total { get; set; }
        public required decimal TotalAfterDocumentDiscount { get; set; }
        public List<CheckoutItemTaxDto> Taxes { get; set; } = new List<CheckoutItemTaxDto>();
    }

    public class CheckoutItemTaxDto
    {
        public required int TaxId { get; set; }
        public required decimal Amount { get; set; }
    }
}
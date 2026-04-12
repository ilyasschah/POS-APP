namespace Api.Models
{
    public class CheckoutPosOrderRequest
    {
        public required int PosOrderId { get; set; }

        public required int PaymentTypeId { get; set; }

        public required decimal AmountPaid { get; set; }

        public required int DocumentTypeId { get; set; }
        public required int WarehouseId { get; set; }
    }
}
namespace Api.Models
{
    public class PosOrderItemDto
    {
        public int Id { get; set; }
        public int PosOrderId { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; } = string.Empty;
        public int RoundNumber { get; set; }
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public bool IsLocked { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public int DiscountAppliedType { get; set; }
        public bool IsFeatured { get; set; }
        public int? VoidedBy { get; set; }
        public string? VoidedByUserName { get; set; }
        public string? Comment { get; set; }
        public DateTime DateCreated { get; set; }
        public string? Bundle { get; set; }
    }

    public class CreatePosOrderItemRequest
    {
        public required int PosOrderId { get; set; }
        public required int ProductId { get; set; }
        public int RoundNumber { get; set; }
        public required decimal Quantity { get; set; }
        public required decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public int DiscountAppliedType { get; set; }
        public string? Comment { get; set; }
        public string? Bundle { get; set; }
    }
    public class BulkAddPosOrderItemRequest
    {
        public int PosOrderId { get; set; }
        public int ProductId { get; set; }
        public int RoundNumber { get; set; }
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public string? Comment { get; set; }
        public string? Bundle { get; set; }
        public int DiscountAppliedType { get; set; }
    }

    public class UpdatePosOrderItemRequest
    {
        public required int Id { get; set; }
        public required decimal Quantity { get; set; }
        public required decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public int DiscountAppliedType { get; set; }
        public string? Comment { get; set; }
    }
}
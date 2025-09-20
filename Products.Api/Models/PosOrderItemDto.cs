namespace Products.Api.Models
{
    public record PosOrderItemDto
    {
        public int Id { get; init; }
        public int PosOrderId { get; init; }
        public int ProductId { get; init; }
        public string ProductName { get; init; }
        public int RoundNumber { get; init; }
        public decimal Quantity { get; init; }
        public decimal Price { get; init; }
        public bool IsLocked { get; init; }
        public decimal Discount { get; init; }
        public int DiscountType { get; init; }
        public bool IsFeatured { get; init; }
        public int? VoidedBy { get; init; }
        public string? VoidedByUserName { get; init; }
        public string? Comment { get; init; }
        public DateTime DateCreated { get; init; }
        public string? Bundle { get; init; }
        public int DiscountAppliedType { get; init; }
    }

    public record CreatePosOrderItemRequest
    {
        public required int PosOrderId { get; init; }
        public required int ProductId { get; init; }
        public int RoundNumber { get; init; } = 0;
        public required decimal Quantity { get; init; }
        public required decimal Price { get; init; }
        public decimal Discount { get; init; } = 0;
        public int DiscountType { get; init; } = 0;
        public string? Comment { get; init; }
        public string? Bundle { get; init; }
    }

    public record UpdatePosOrderItemRequest
    {
        public required int Id { get; init; }
        public required decimal Quantity { get; init; }
        public required decimal Price { get; init; }
        public decimal Discount { get; init; }
        public string? Comment { get; init; }
    }
}



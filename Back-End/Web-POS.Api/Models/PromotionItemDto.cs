namespace Api.Models
{
    public class PromotionItemDto
    {
        public int Id { get; set; }
        public int PromotionId { get; set; }
        public int ProductId { get; set; }
        //public int Uid { get; set; }
        public int DiscountType { get; set; }
        public int PriceType { get; set; }
        public decimal Value { get; set; }
        public bool IsConditional { get; set; }
        public decimal Quantity { get; set; }
        public int ConditionType { get; set; }
        public decimal QuantityLimit { get; set; }
    }
    public class CreateSinglePromotionItemRequest
    {
        public required int PromotionId { get; set; }
        public required int ProductId { get; set; }
        public required int DiscountType { get; set; }
        public required int PriceType { get; set; }
        public required decimal Value { get; set; }
        public required bool IsConditional { get; set; }
        public required decimal Quantity { get; set; }
        public required int ConditionType { get; set; }
        public required decimal QuantityLimit { get; set; }
    }
    public class CreatePromotionItemRequest
    {
        public int ProductId { get; set; }
        public int DiscountType { get; set; }
        public int PriceType { get; set; }
        public decimal Value { get; set; }
        public bool IsConditional { get; set; }
        public decimal Quantity { get; set; }
        public int ConditionType { get; set; }
        public decimal QuantityLimit { get; set; }
    }
    public class UpdatePromotionItemRequest
    {
        public required int Id { get; set; }
        public required int ProductId { get; set; }
        public required int DiscountType { get; set; }
        public required int PriceType { get; set; }
        public required decimal Value { get; set; }
        public required bool IsConditional { get; set; }
        public required decimal Quantity { get; set; }
        public required int ConditionType { get; set; }
        public required decimal QuantityLimit { get; set; }
    }
}
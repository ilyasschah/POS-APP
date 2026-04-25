namespace Api.Models
{
    //public class PromotionItemDto
    //{
    //    public int Id { get; set; }
    //    public int PromotionId { get; set; }
    //    public int Uid { get; set; }
    //    public int DiscountType { get; set; }
    //    public int PriceType { get; set; }
    //    public decimal Value { get; set; }
    //    public bool IsConditional { get; set; }
    //    public decimal Quantity { get; set; }
    //    public int ConditionType { get; set; }
    //    public decimal QuantityLimit { get; set; }
    //}
    public class PromotionDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Name { get; set; } = string.Empty;
        public DateTime? StartDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? EndTime { get; set; }
        public int DaysOfWeek { get; set; }
        public bool IsEnabled { get; set; }
        public List<PromotionItemDto> Items { get; set; } = new List<PromotionItemDto>();
    }

    

    //public class CreatePromotionItemRequest
    //{
    //    public int Uid { get; set; }
    //    public int DiscountType { get; set; }
    //    public int PriceType { get; set; }
    //    public decimal Value { get; set; }
    //    public bool IsConditional { get; set; }
    //    public decimal Quantity { get; set; }
    //    public int ConditionType { get; set; }
    //    public decimal QuantityLimit { get; set; }
    //}
    public class CreatePromotionRequest
    {
        public required string Name { get; set; }
        public required int DaysOfWeek { get; set; }
        public DateTime? StartDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? EndTime { get; set; }
        public List<CreatePromotionItemRequest> Items { get; set; } = new List<CreatePromotionItemRequest>();
    }

    
    //public class UpdatePromotionItemRequest
    //{
    //    public required int Id { get; set; }
    //    public required int Uid { get; set; }
    //    public required int DiscountType { get; set; }
    //    public required int PriceType { get; set; }
    //    public required decimal Value { get; set; }
    //    public required bool IsConditional { get; set; }
    //    public required decimal Quantity { get; set; }
    //    public required int ConditionType { get; set; }
    //    public required decimal QuantityLimit { get; set; }
    //}
    public class UpdatePromotionRequest
    {
        public required int Id { get; set; }
        public required string Name { get; set; }
        public required int DaysOfWeek { get; set; }
        public required bool IsEnabled { get; set; }
        public DateTime? StartDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? EndTime { get; set; }
        public List<UpdatePromotionItemRequest> Items { get; set; } = new List<UpdatePromotionItemRequest>();
    }
}
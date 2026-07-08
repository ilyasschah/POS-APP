namespace Api.Models
{
    
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
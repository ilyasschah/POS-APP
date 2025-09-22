using System;

namespace Products.Api.Models
{
    public class PromotionDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public DateTime? StartDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? EndTime { get; set; }
        public int DaysOfWeek { get; set; }
        public bool IsEnabled { get; set; }
    }

    public class CreatePromotionRequest
    {
        public required string Name { get; set; }
        public DateTime? StartDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? EndTime { get; set; }
        public required int DaysOfWeek { get; set; }
        public bool? IsEnabled { get; set; }
    }

    public class UpdatePromotionRequest
    {
        public required string Name { get; set; }
        public DateTime? StartDate { get; set; }
        public TimeSpan? StartTime { get; set; }
        public DateTime? EndDate { get; set; }
        public TimeSpan? EndTime { get; set; }
        public required int DaysOfWeek { get; set; }
        public required bool IsEnabled { get; set; }
    }
}
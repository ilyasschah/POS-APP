using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperPromotion
    {
        public static PromotionDto MapToPromotionDto(Promotion entity)
        {
            return new PromotionDto
            {
                Id = entity.Id,
                Name = entity.Name,
                StartDate = entity.StartDate,
                StartTime = entity.StartTime,
                EndDate = entity.EndDate,
                EndTime = entity.EndTime,
                DaysOfWeek = entity.DaysOfWeek,
                IsEnabled = entity.IsEnabled
            };
        }
    }
}
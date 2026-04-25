using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperPromotion
    {
        public static PromotionDto MapToDto(Promotion entity, List<PromotionItem> items)
        {
            return new PromotionDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                Name = entity.Name,
                StartDate = entity.StartDate,
                StartTime = entity.StartTime,
                EndDate = entity.EndDate,
                EndTime = entity.EndTime,
                DaysOfWeek = entity.DaysOfWeek,
                IsEnabled = entity.IsEnabled,
                Items = items.Select(i => new PromotionItemDto
                {
                    Id = i.Id,
                    PromotionId = i.PromotionId,
                    Uid = i.Uid,
                    DiscountType = i.DiscountType,
                    PriceType = i.PriceType,
                    Value = i.Value,
                    IsConditional = i.IsConditional,
                    Quantity = i.Quantity,
                    ConditionType = i.ConditionType,
                    QuantityLimit = i.QuantityLimit
                }).ToList()
            };
        }
    }
}
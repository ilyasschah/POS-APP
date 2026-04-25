using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperPromotionItem
    {
        public static PromotionItemDto MapToDto(PromotionItem entity)
        {
            return new PromotionItemDto
            {
                Id = entity.Id,
                PromotionId = entity.PromotionId,
                Uid = entity.Uid,
                DiscountType = entity.DiscountType,
                PriceType = entity.PriceType,
                Value = entity.Value,
                IsConditional = entity.IsConditional,
                Quantity = entity.Quantity,
                ConditionType = entity.ConditionType,
                QuantityLimit = entity.QuantityLimit
            };
        }
    }
}
using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperPosOrderItem
    {
        public static PosOrderItemDto MapToPosOrderItemDto(PosOrderItem entity)
        {
            return new PosOrderItemDto
            {
                Id = entity.Id,
                PosOrderId = entity.PosOrderId,
                ProductId = entity.ProductId,

                ProductName = entity.Product?.Name ?? "Unknown Product",

                RoundNumber = entity.RoundNumber,
                Quantity = entity.Quantity,
                Price = entity.Price,
                IsLocked = entity.IsLocked,
                Discount = entity.Discount,
                DiscountType = entity.DiscountType,
                DiscountAppliedType = entity.DiscountAppliedType,
                IsFeatured = entity.IsFeatured,
                VoidedBy = entity.VoidedBy,

                VoidedByUserName = entity.VoidedByUser?.Username ?? "N/A",

                Comment = entity.Comment,
                DateCreated = entity.DateCreated,
                Bundle = entity.Bundle
            };
        }
    }
}
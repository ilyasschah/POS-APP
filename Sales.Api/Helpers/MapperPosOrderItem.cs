using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers
{
    public static class MapperPosOrderItem
    {
        public static PosOrderItemDto MapToPosOrderItemDto(PosOrderItem item)
        {
            return new PosOrderItemDto
            {
                Id = item.Id,
                PosOrderId = item.PosOrderId,
                ProductId = item.ProductId,
                ProductName = item.Product?.Name ?? "N/A",
                RoundNumber = item.RoundNumber,
                Quantity = item.Quantity,
                Price = item.Price,
                IsLocked = item.IsLocked,
                Discount = item.Discount,
                DiscountType = item.DiscountType,
                IsFeatured = item.IsFeatured,
                VoidedBy = item.VoidedBy,
                VoidedByUserName = item.VoidedByUser?.Username?? "N/A",
                Comment = item.Comment,
                DateCreated = item.DateCreated,
                Bundle = item.Bundle,
                DiscountAppliedType = item.DiscountAppliedType
            };
        }
    }
}

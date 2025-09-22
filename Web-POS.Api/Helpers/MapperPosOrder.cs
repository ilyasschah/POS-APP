using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperPosOrder
    {
        public static PosOrderDto MapToPosOrderDto(PosOrder entity)
        {
            return new PosOrderDto
            {
                Id = entity.Id,
                UserId = entity.UserId,
                Number = entity.Number,
                Discount = entity.Discount,
                DiscountType = entity.DiscountType,
                Total = entity.Total,
                CustomerId = entity.CustomerId,
                UserName = entity.User?.Username ?? "N/A",
                CustomerName = entity.Customer?.Name ?? "N/A"
            };
        }
    }
}
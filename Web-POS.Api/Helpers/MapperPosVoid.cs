// FILE: Products.Api.Helpers\MapperPosVoid.cs

using Api.Domain;
using Api.Models;

namespace Api.Helpers;

public static class MapperPosVoid
{
    public static PosVoidDto MapToPosVoidDto(PosVoid entity)
    {
        return new PosVoidDto
        {
            Id = entity.Id,
            CompanyId = entity.CompanyId,
            OrderNumber = entity.OrderNumber,
            UserName = entity.UserName,
            ProductName = entity.ProductName,
            Quantity = entity.Quantity,
            Price = entity.Price,
            Discount = entity.Discount,
            DiscountType = entity.DiscountType,
            Total = entity.Total,
            IsConfirmed = entity.IsConfirmed,
            Reason = entity.Reason,
            VoidedByName = entity.VoidedByName,
            DateCreated = entity.DateCreated,
            DateVoided = entity.DateVoided
        };
    }
}

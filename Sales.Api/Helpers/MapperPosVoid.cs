// FILE: Sales.Api.Helpers\MapperPosVoid.cs

using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers;

public static class MapperPosVoid
{
    public static PosVoidDto MapToPosVoidDto(PosVoid entity)
    {
        return new PosVoidDto
        {
            Id = entity.Id,
            OrderNumber = entity.OrderNumber,
            UserName = entity.UserName,
            ProductName = entity.ProductName,
            Quantity = entity.Quantity,
            Price = entity.Price,
            Total = entity.Total,
            IsConfirmed = entity.IsConfirmed,
            Reason = entity.Reason,
            VoidedByName = entity.VoidedByName,
            DateVoided = entity.DateVoided
        };
    }
}

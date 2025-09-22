// FILE: Products.Api.Helpers\MapperStockControl.cs

using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers;

public static class MapperStockControl
{
    public static StockControlDto MapToStockControlDto(StockControl entity)
    {
        return new StockControlDto
        {
            Id = entity.Id,
            ProductId = entity.ProductId,
            ProductName = entity.Product?.Name ?? "N/A",
            CustomerId = entity.CustomerId,
            CustomerName = entity.Customer?.Name ?? "N/A",
            ReorderPoint = entity.ReorderPoint,
            PreferredQuantity = entity.PreferredQuantity,
            IsLowStockWarningEnabled = entity.IsLowStockWarningEnabled,
            LowStockWarningQuantity = entity.LowStockWarningQuantity
        };
    }
}
